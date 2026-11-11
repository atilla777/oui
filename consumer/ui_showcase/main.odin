package main

import app "app"
import "core:os"

main :: proc() {if !app.run(os.args[1:]) {os.exit(1)}}
