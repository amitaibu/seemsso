module Utils.Json
    exposing
        ( decodeDate
        , decodeEmptyArrayAs
        , decodeInt
        )

{-| If given an empty array, decodes it as the given value. Otherwise, fail.
-}

import Date exposing (Date)
import Json.Decode exposing (Decoder, andThen, dict, fail, field, float, int, list, map, map2, nullable, oneOf, string, succeed, value)
import Json.Decode.Extra exposing (date)


{-| Decodes date from string or from Epoch (i.e. number).
-}
decodeDate : Decoder Date
decodeDate =
    oneOf
        [ date
        , decodeDateFromEpoch
        ]


{-| Decodes date from Epoch (i.e. number).
-}
decodeDateFromEpoch : Decoder Date
decodeDateFromEpoch =
    map Date.fromTime float


decodeEmptyArrayAs : a -> Decoder a
decodeEmptyArrayAs default =
    list value
        |> andThen
            (\list ->
                let
                    length =
                        List.length list
                in
                if length == 0 then
                    succeed default
                else
                    fail <| "Expected an empty array, not an array with length: " ++ toString length
            )


{-| Cast String to Int.
-}
decodeInt : Decoder Int
decodeInt =
    oneOf
        [ int
        , string
            |> andThen (resultToDecoder << String.toFloat)
            |> map floor
        ]


resultToDecoder : Result String a -> Decoder a
resultToDecoder res =
    case res of
        Ok x ->
            Json.Decode.succeed x

        Err err ->
            Json.Decode.fail err
