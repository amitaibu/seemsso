module Homepage.View exposing (..)

import App.Types exposing (Language(..))
import Homepage.Model exposing (Model, Msg(..))
import Html exposing (..)
import Html.Attributes exposing (alt, class, classList, href, placeholder, src, style, target, type_, value)
import Html.Events exposing (onClick, onInput)
import Json.Encode exposing (string)
import Utils.Html exposing (divider, sectionDivider, showIf, showMaybe)


view : Model -> Html Msg
view model =
    div [] [ text "Homepage" ]
