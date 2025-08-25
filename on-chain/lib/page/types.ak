use aiken/transaction.{OutputReference}

pub type Params {
  seed: OutputReference,
  max_page_size: Int,
}

pub type Datum {
  page: Page,
  version: Int,
  next: Name,
}

pub type Page =
  Pairs<ByteArray, Data>

pub type Name =
  ByteArray

pub type RedMint {
  MintInit
  MintMint
  MintBurn
  MintEnd
}

pub type RedSpend {
  SpendInsert
  SpendUpdate
  SpendCollect
  SpendBurn
  SpendRemove
  SpendEnd
}

pub type MintType {
  name: Name,
  is_mint: Bool,
}

pub type RedWrap {
  Junk
  Wrap(RedSpend)
}
