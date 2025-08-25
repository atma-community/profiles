use aiken/bytearray as ba
use aiken/cbor.{serialise}
use aiken/dict.{keys, to_pairs}
use aiken/pairs.{get_first}
use aiken/list.{any, filter, find, has, length, map}
use aiken/transaction.{
  InlineDatum, Input, Mint, Output, OutputReference, Redeemer, ScriptContext,
  ScriptPurpose, Spend, Transaction,
}
use aiken/transaction/credential.{ScriptCredential}
use aiken/transaction/value.{
  PolicyId, Value, flatten, from_minted_value, lovelace_of, policies,
  quantity_of, tokens, without_lovelace,
}
use page/shared.{
  dummy_datum, max_name, script_token, script_token_label, user_token,
  user_token_label,
}
use page/types as t

fn get_mint_type(pid: PolicyId, value: Value) {
  // Order is lexigraphical
  expect [Pair (stn, qty0), Pair (utn, qty1)] = value |> tokens(pid) |> to_pairs()
  // Check prefices
  expect (ba.take(stn, 4) == script_token_label())?
  expect (ba.take(utn, 4) == user_token_label())?
  // Check names agree
  let name = ba.drop(stn, 4)
  expect name == ba.drop(utn, 4)
  // Check quanities are sensible
  let is_mint =
    when (qty0, qty1) is {
      (1, 1) -> True
      (-1, -1) -> False
      _ -> fail @"bad mint"
    }
  t.MintType { name, is_mint }
}

/// Script token must be the exclusive non ada value.
fn name_from_script_value(pid: PolicyId, val: Value) {
  let label = script_token_label()
  expect [(pid_, stn, qty)] = val |> without_lovelace() |> flatten()
  expect and {
      (qty == 1)?,
      (pid_ == pid)?,
    }
  expect (ba.take(stn, 4) == label)?
  ba.drop(stn, 4)
}

fn name_from_user_value(pid: PolicyId, val: Value) {
  let label = user_token_label()
  expect [Pair (stn, qty)] = val |> tokens(pid) |> to_pairs()
  expect (qty == 1)?
  expect (ba.take(stn, 4) == label)?
  ba.drop(stn, 4)
}

validator(params: t.Params) {
  fn spend(dat: t.Datum, red: t.RedSpend, ctx: ScriptContext) {
    trace @"spend0"
    let ScriptContext { transaction, purpose } = ctx
    trace @"spend1"
    expect Spend(own_oref) = purpose
    let Transaction { inputs, outputs, mint, reference_inputs, .. } =
      transaction
    expect Some(own_input) =
      list.find(inputs, fn(input) { input.output_reference == own_oref })

    let Input {
      output: Output { address: own_address, value: own_value, .. },
      ..
    } = own_input
    let pid =
      when own_address.payment_credential is {
        ScriptCredential(hash) -> hash
        _ -> fail @"Not a script"
      }

    let own_mint = mint |> from_minted_value()

    let t.Datum { page: own_page, version: own_version, next: own_next } = dat

    trace @"cases"
    when red is {
      t.SpendInsert -> {
        let own_name = name_from_script_value(pid, own_value)
        // Mint precisely cip-68 pair 
        let t.MintType { name: mint_name, is_mint } =
          get_mint_type(pid, own_mint)
        expect is_mint?
        // Own name is strictly less than Mint name
        expect Less = own_name |> ba.compare(mint_name)
        // Mint name strictly less than own next
        expect Less = mint_name |> ba.compare(own_next)

        expect Some(root) = 
          if ba.compare("",own_name) == Equal {
            Some(own_input)
          } else {
              reference_inputs
                |> find(
                     fn(i) {
                       ( i.output.value |> quantity_of(pid, script_token("")) ) == 1
                     },
                   )
          }
        
        let Output { datum: root_datum, .. } = root.output
        expect InlineDatum(root_datum) = root_datum
        expect root_datum: t.Datum = root_datum

        expect Some(insert_fee_bytes) = root_datum.page |> get_first("insert_fee")
        expect insert_fee: Int = insert_fee_bytes

        when outputs is {
          [continuing_output, new_output, fee_output, ..] -> {
            // Continuing output 
            let Output {
              value: continuing_value,
              address: continuing_address,
              datum: continuing_datum,
              ..
            } = continuing_output
            // Address is own address
            expect (continuing_address == own_address)?
            // Value is ada and own script token
            let continuing_name = name_from_script_value(pid, continuing_value)
            expect (continuing_name == own_name)?
            // Continuing datum
            expect InlineDatum(continuing_datum) = continuing_datum
            expect continuing_datum: t.Datum = continuing_datum
            let t.Datum {
              page: continuing_page,
              version: continuing_version,
              next: continuing_next,
            } = continuing_datum
            // Check continuing datum 
            expect and {
                continuing_page == own_page,
                continuing_version == own_version,
                continuing_next == mint_name,
              }?
            // New output
            let Output {
              value: new_value,
              address: new_address,
              datum: new_datum,
              ..
            } = new_output
            // Address is own address 
            expect new_address == own_address
            // Value is ada and mint script token
            let new_name = name_from_script_value(pid, new_value)
            expect (new_name == mint_name)?
            // New datum
            expect InlineDatum(new_datum) = new_datum
            expect new_datum: t.Datum = new_datum
            let t.Datum { page: new_page, version: new_version, next: new_next } =
              new_datum
            expect and {
                ( serialise(new_page) |> ba.length() ) < params.max_page_size,
                new_version == own_version,
                new_next == own_next,
              }
            // Fee output
            let Output {
              value: fee_value,
              address: fee_address,
              datum: fee_datum,
              ..
            } = fee_output
            // Address is own address
            expect fee_address == own_address
            // Value is ada of >= insert fee
            expect ( fee_value |> policies() |> length() ) == 1
            expect ( fee_value |> lovelace_of() ) >= insert_fee
            // Datum is fee datum
            expect InlineDatum(fee_datum) = fee_datum
            let dummy_data : Data = dummy_datum()
            expect fee_datum == dummy_data
            True
          }
          _ -> False
        }
      }
      t.SpendUpdate -> {
        let own_name = name_from_script_value(pid, own_value)
        when outputs is {
          [continuing_output, user_output, ..] -> {
            // Continuing output 
            let Output {
              value: continuing_value,
              address: continuing_address,
              datum: continuing_datum,
              ..
            } = continuing_output
            // Address is own address 
            expect continuing_address == own_address
            // Value is ada and own script token
            let continuing_name = name_from_script_value(pid, continuing_value)
            expect continuing_name == own_name
            // Datum is own datum with updated page; page size is less than max page size
            expect InlineDatum(continuing_datum) = continuing_datum
            expect continuing_datum: t.Datum = continuing_datum
            let t.Datum {
              page: continuing_page,
              version: continuing_version,
              next: continuing_next,
            } = continuing_datum
            let Output { value: user_value, .. } = user_output
            // Check Continuing datum 
            expect and {
                ( serialise(continuing_page) |> ba.length() ) < params.max_page_size,
                continuing_version == own_version,
                continuing_next == own_next,
              }
            // User output contains user token
            let user_name = name_from_user_value(pid, user_value)
            expect user_name == own_name
            True
          }
          _ -> False
        }
      }
      t.SpendCollect -> {
        // Check has no token
        expect [] = own_value |> tokens(pid) |> to_pairs()
        // Check spend admin token
        when outputs is {
          [admin_output, ..] -> {
            let qty = admin_output.value |> quantity_of(pid, user_token(""))
            qty == 1
          }
          _ -> False
        }
      }
      t.SpendBurn -> {
        let own_name = name_from_script_value(pid, own_value)
        // Burn precisely cip-68 pair
        let t.MintType { name: mint_name, is_mint } =
          get_mint_type(pid, own_mint)
        expect !is_mint?
        expect mint_name == own_name
        True
      }
      t.SpendRemove -> {
        let own_name = name_from_script_value(pid, own_value)

        // Burn precisely cip-68 pair 
        let t.MintType { name: mint_name, is_mint } =
          get_mint_type(pid, own_mint)
        expect !is_mint?
        // Own next is mint name 
        expect own_next == mint_name
        // Find burn next
        expect Some(burn_input) =
          inputs
            |> find(
                 fn(i) {
                   let qty =
                     i.output.value
                       |> quantity_of(pid, script_token(mint_name))
                   qty == 1
                 },
               )
        let Input { output: Output { datum: burn_datum, .. }, .. } = burn_input
        expect InlineDatum(burn_dat) = burn_datum
        expect t.Datum { next: burn_next, .. }: t.Datum = burn_dat

        when outputs is {
          [continuing_output, ..] -> {
            // Continuing output 
            let Output {
              value: continuing_value,
              address: continuing_address,
              datum: continuing_datum,
              ..
            } = continuing_output
            // Address is own address 
            expect continuing_address == own_address
            // Value is ada and own script token
            let continuing_name = name_from_script_value(pid, continuing_value)
            expect continuing_name == own_name
            // Datum is own datum with updated next
            expect InlineDatum(continuing_datum) = continuing_datum
            expect continuing_datum: t.Datum = continuing_datum
            let t.Datum {
              page: continuing_page,
              version: continuing_version,
              next: continuing_next,
            } = continuing_datum
            // Check Continuing datum 
            expect and {
                continuing_page == own_page,
                continuing_version == own_version,
                continuing_next == burn_next,
              }
            True
          }
          _ -> False
        }
      }
      t.SpendEnd -> {
        let own_name = name_from_script_value(pid, own_value)
        // Own name is empty
        expect own_name == ""
        // Own next is max name
        expect own_next == max_name()
        // Burn Precisely cip-68 pair with own name
        let t.MintType { name: mint_name, is_mint } =
          get_mint_type(pid, own_mint)
        expect !is_mint?
        expect mint_name == own_name
        True
      }
    }
  }

  fn mint(red: t.RedMint, ctx: ScriptContext) {
    let ScriptContext { transaction, purpose } = ctx
    expect Mint(pid) = purpose
    let Transaction { inputs, outputs, mint, redeemers, .. } = transaction

    let spend_redeemers = script_token_spend_redeemers(pid, inputs, redeemers)
    when red is {
      t.MintInit -> {
        // Spend seed
        expect True = inputs |> any(fn(i) { i.output_reference == params.seed })

        // Mint precisely cip-68
        let t.MintType { name: own_name, is_mint } =
          get_mint_type(pid, mint |> from_minted_value())
        expect is_mint
        // Own name is empty
        expect own_name == ""
        when outputs is {
          [init_output, ..] -> {
            // 0th output is init output 
            let Output {
              value: init_value,
              address: init_address,
              datum: init_datum,
              ..
            } = init_output
            // Address is own address
            expect ScriptCredential(hash) = init_address.payment_credential
            expect hash == pid
            // Value is ada and own script token
            let init_name = name_from_script_value(pid, init_value)
            expect init_name == own_name
            expect InlineDatum(init_datum) = init_datum
            expect init_datum: t.Datum = init_datum
            let t.Datum {
              page: init_page,
              version: init_version,
              next: init_next,
            } = init_datum
            expect and {
                ( serialise(init_page) |> ba.length() ) <= params.max_page_size,
                init_version >= 0,
                init_next == max_name(),
              }
            True
          }
          _ -> False
        }
      }
      t.MintMint -> spend_redeemers == [t.SpendInsert]
      t.MintBurn -> and {
          spend_redeemers |> has(t.SpendBurn),
          spend_redeemers |> has(t.SpendRemove),
        }
      t.MintEnd -> spend_redeemers == [t.SpendEnd]
    }
  }
}

// This is invoked only on minting purpose. 
// There is no good reason why the size of redeemer dict would be large under normal use.
// Thus we make no effort to optimize for this.

fn script_token_spend_redeemers(
  pid: PolicyId,
  inputs: List<Input>,
  redeemers: Pairs<ScriptPurpose, Redeemer>,
) -> List<t.RedSpend> {
  inputs
    |> filter(fn(i) { is_item(pid, i.output) })
    |> map(fn(i) { spend_redeemer(i.output_reference, redeemers) })
}

// Check output belongs to list
fn is_item(pid: PolicyId, output: Output) -> Bool {
  let label = script_token_label()
  let has_st =
    output.value
      |> tokens(pid)
      |> keys()
      |> any(fn(an) { ba.take(an, 4) == label })
  if has_st {
    // Note that globally this is redundant:
    // there is no way a script token could not be at the script address.
    // We enforce this locally
    when output.address.payment_credential is {
      ScriptCredential(h) -> h == pid
      _ -> False
    }
  } else {
    False
  }
}

// Multi-purpose validators have an extra wrapped spend redeemer
fn spend_redeemer(
  oref: OutputReference,
  redeemers: Pairs<ScriptPurpose, Redeemer>,
) -> t.RedSpend {
  expect Some(data) = redeemers |> get_first(Spend(oref))
  expect redw: t.RedWrap = data
  expect t.Wrap(inner) = redw
  inner
}
