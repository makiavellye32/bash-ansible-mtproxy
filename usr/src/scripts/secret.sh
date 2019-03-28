#!/bin/bash

c_secret=yoursecret
c_url='https://api.telegram.org/bot<token>/sendMessage'
c_header='Content-Type: application/json'
c_chat_id='"chat_id":"yourchatid"'
c_text='"text":"Новый secret для прокси'

c_json_begin='{'
c_json_end='}'
c_json_separator=','
c_json_field_frontier='"'


v_json=$c_json_begin
v_json+=$c_chat_id
v_json+=$c_json_separator
v_json+=$c_text
v_json+=$c_secret
v_json+=$c_json_field_frontier
v_json+=$c_json_end

#echo $v_json;
curl -d "$v_json" -H "$c_header" -X POST $c_url;
