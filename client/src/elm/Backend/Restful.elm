module Backend.Restful
    exposing
        ( EndPoint
        , Entity
        , EntityDictList
        , get
        , decodeSingleEntity
        , decodeId
        , decodeStorageTuple
        , EntityId
        , toEntityId
        , fromEntityId
        , decodeEntityId
        , encodeEntityId
        )

{-| This is the beginnings of some general code, eventually to be published
as `Gizra/elm-drupal`. But it's easier to start working with it here --
I'll publish it separately once it gels a little.
-}

import EveryDictList exposing (EveryDictList)
import Http exposing (Error, expectJson)
import HttpBuilder exposing (..)
import Json.Decode exposing (Decoder, field, index, list, map, map2)
import Json.Encode exposing (Value)
import Maybe.Extra
import StorageKey exposing (StorageKey(..))
import Utils.Json exposing (decodeInt)


{-| This is a start at a nicer idiom for dealing with backend JSON endpoints.
It's similar in prinicple to the `UpsertConfig` in `Measurement.Update`, and
the concepts ought to be merged eventually. (I'm focusing on `get` for the
moment, but eventually this is meant to handle all the CRUD operations, plus
specialities like `upsert`.)

The basic idea is to include in this type all those things about an endpoint
which don't change. For instance, we know the path of the endpoint, what kind
of JSON it emits, etc. -- that never varies.

In the type parameters:

    - the `key` is the type of the wrapper around `Int` for the node id.
    - the `value` is the type of the value
    - the `params` is a type for the query params that this endpoint takes
      If your endpoint doesn't take params, just use `()` (or, a phantom
      type variable, if you like).
    - the `error` is the error type. If you don't want to do something
      special with errors, then it can just be `Http.Error`

-}
type alias EndPoint error params key value =
    -- The relative path to the endpoint ... that is, the part after `/api/`
    { path : String

    -- The tag which wraps the integer node ID. (This assumes an integer node
    -- ID ... we could make it more general someday if needed).
    , tag : Int -> key

    -- A decoder for the values
    , decoder : Decoder value

    -- You may want to use your own error type. If so, provided something
    -- that maps from the kind of `Http.Error` this endpoint produces to
    -- your local error type. If you just want to use `Http.Error` dirdctly
    -- as the error type, then you can supply `identity`.
    , error : Http.Error -> error

    -- This takes your typed `params` and turns them into something that
    -- we can feed into `withQueryParams`. So, we get compile-time type-safety
    -- for our params ... isn't that nice? And you could use `Maybe` judiciously
    -- in your `params` type if you want some or all params to be optional.
    --
    -- If you never take params, then you can supply `always []`
    , params : params -> List ( String, String )
    }


{-| Roughtly analogous to Yesod's `Entity` ... the combination of an ID and a value.

For now, it's just a type alias for a Tuple, where the first element is a StorageKey.

-}
type alias Entity key value =
    ( StorageKey key, value )


{-| It woudld be natural to put entities in a DictList, so here's a type to make
that less verbose.
-}
type alias EntityDictList key value =
    EveryDictList (StorageKey key) value


{-| Appends left-to-right, joining with a "/" if needed.
-}
(</>) : String -> String -> String
(</>) left right =
    if String.endsWith "/" left || String.startsWith "/" right then
        left ++ right
    else
        left ++ "/" ++ right


{-| Get entities from an endpoint.

What we hand you is a `Result` with a list of entities, since that is the most
"natural" thing to hand back. You can convert it to a `RemoteData` easily with
a `RemoteData.fromResult` if you like.

The `error` type parameter allows the endpoint to have locally-typed errors. You
can just use `Http.Error`, though, if you want to.

-}
get : String -> Maybe String -> EndPoint error params key value -> params -> (Result error (List (Entity key value)) -> msg) -> Cmd msg
get backendUrl accessToken endpoint params tagger =
    let
        queryParams =
            accessToken
                |> Maybe.Extra.toList
                |> List.map (\token -> ( "access_token", token ))
                |> List.append (endpoint.params params)
    in
        HttpBuilder.get (backendUrl </> endpoint.path)
            |> withQueryParams queryParams
            |> withExpect (expectJson (decodeData (list (decodeStorageTuple (decodeId endpoint.tag) endpoint.decoder))))
            |> send (Result.mapError endpoint.error >> tagger)


{-| Convenience for the pattern where you have a field called "id",
and you want to wrap the result in a type (e.g. PersonId Int). You can
just use `decodeId PersonId`.
-}
decodeId : (Int -> a) -> Decoder a
decodeId wrapper =
    map wrapper (field "id" decodeInt)


{-| Convenience for the case where you have a decoder for the ID,
a decoder for the value, and you want to decode a tuple of StorageKey and
value.
-}
decodeStorageTuple : Decoder key -> Decoder value -> Decoder ( StorageKey key, value )
decodeStorageTuple keyDecoder valueDecoder =
    map2 (,)
        (map Existing keyDecoder)
        valueDecoder


decodeData : Decoder a -> Decoder a
decodeData =
    field "data"


{-| Given a decoder for an entity, applies it to the kind of response the baceknd
sends when you do a PUT, POST, or PATCH.

For instance, if you POST an entity, backend will send back the JSON for that entity,
as the single element of an array, then wrapped in a `data` field, e.g.:

    { data :
        [
            {
                id: 27,
                label: "The label",
                ...
            }
        ]
    }

To decode this, write a decoder for the "inner" part (the actual entity), and then
supply that as a parameter to `decodeSingleEntity`.

-}
decodeSingleEntity : Decoder a -> Decoder a
decodeSingleEntity =
    decodeData << index 0


{-| This is a wrapper for an `Int` id. It takes a "phantom" type variable
in order to gain type-safety about what kind of entity it is an ID for.
So, to specify that you have an id for a clinic, you would say:

    clinidId : EntityId ClinicId

-}
type EntityId a
    = EntityId Int


{-| This is how you create a EntityId, if you have an `Int`. You can create
any kind of `EntityId` this way ... so you would normally only do this in
situations that are fundamentally untyped, such as when you are decoding
JSON data. Except in those kind of "boundary" situations, you should be
working with the typed EntityIds.
-}
toEntityId : Int -> EntityId a
toEntityId =
    EntityId


{-| This is how you get an `Int` back from a `EntityId`. You should only use
this in boundary situations, where you need to send the id out in an untyped
way. Normally, you should just pass around the `EntityId` itself, to retain
type-safety.
-}
fromEntityId : EntityId a -> Int
fromEntityId (EntityId a) =
    a


{-| Decodes a EntityId.

This just turns JSON int (or string that is an int) to a EntityId. You need
to supply the `field "id"` yourself, if necessary, since id's could be present
in other fields as well.

This decodes any kind of EntityId you like (since there is fundamentally no type
information in the JSON iself, of course). So, you need to verify that the type
is correct yourself.

-}
decodeEntityId : Decoder (EntityId a)
decodeEntityId =
    Json.Decode.map toEntityId decodeInt


{-| Encodes any kind of `EntityId` as a JSON int.
-}
encodeEntityId : EntityId a -> Value
encodeEntityId =
    Json.Encode.int << fromEntityId
