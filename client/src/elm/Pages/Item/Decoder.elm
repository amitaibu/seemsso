module Pages.Item.Decoder
    exposing
        ( deocdeItemIdAndComments
        )

import DictList exposing (DictList, decodeArray2, empty)
import Item.Decoder exposing (decodeItemId)
import Item.Model exposing (EveryDictListItems, Item, ItemId)
import Json.Decode exposing (Decoder, andThen, at, dict, fail, field, float, index, int, keyValuePairs, list, map, map2, nullable, oneOf, string, succeed)
import Json.Decode.Pipeline exposing (custom, decode, optional, optionalAt, required, requiredAt)
import Utils.Json exposing (decodeEmptyArrayAs, decodeInt)


deocdeItemIdAndComments : Decoder ( ItemCommentId, List ItemComment )
deocdeItemIdAndComments =
    oneOf
        [ decodeArray2 (field "id" decodeItemId) decodeItem
        , decodeEmptyArrayAs DictList.empty
        ]



-- decodeItemId : Decoder ItemId
-- decodeItemId =
--     decodeInt |> Decode.map ItemId


decodeItemId : Decoder ItemId
decodeItemId =
    decodeInt


decodeItem : Decoder Item
decodeItem =
    decode Item
        |> required "name" string
