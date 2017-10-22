module Backend.Item.Model
    exposing
        ( Item
        , ItemComment
        , Msg(..)
        )

import Backend.Entities exposing (ItemCommentId, ItemId)
import Backend.Restful exposing (EntityDictList)
import Date exposing (Date)
import Editable.WebData exposing (EditableWebData)
import Http
import StorageKey exposing (StorageKey)
import User.Model exposing (UserTuple)


type alias Item =
    { name : String
    , comments : EntityDictList ItemCommentId (EditableWebData ItemComment)
    }


type alias ItemComment =
    { user : UserTuple
    , comment : String
    , created : Date
    }


type Msg
    = HandleFetchItems (Result String (EntityDictList ItemId Item))
    | HandleFetchItemIdAndCommentsTuple (Result String ( StorageKey ItemId, EntityDictList ItemCommentId (EditableWebData ItemComment) ))
    | SaveComment ( StorageKey ItemId, StorageKey ItemCommentId )
    | HandleSaveComment ( StorageKey ItemId, StorageKey ItemCommentId ) (Result Http.Error (EntityDictList ItemCommentId (EditableWebData ItemComment)))
