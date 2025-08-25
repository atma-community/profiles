use aiken/bytearray.{concat}
use page/types as t

pub fn user_token_label() -> ByteArray {
  #"000de140"
}

pub fn script_token_label() -> ByteArray {
  #"000643b0"
}

pub fn dummy_datum() -> t.Datum {
  t.Datum { page: [], version: -999, next: "" }
}

pub fn user_token(name: t.Name) {
  user_token_label() |> concat(name)
}

pub fn script_token(name: t.Name) {
  script_token_label() |> concat(name)
}

pub fn max_name() -> t.Name {
  #[
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
  ]
}
