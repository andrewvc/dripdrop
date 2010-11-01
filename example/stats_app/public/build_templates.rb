#!/usr/bin/env ruby
#Compile the HAML and SASS templates

`haml stats.haml > stats.html`
`sass stats.scss > stats.css`
