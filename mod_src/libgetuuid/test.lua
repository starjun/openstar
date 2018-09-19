#!/usr/bin/env lua
local uuid = require "libgetuuid"

local uuid_str = uuid.getuuid()
print(uuid_str)
local salt_uuid_str = uuid.getuuid("aaa")
print("salt uuid:"..salt_uuid_str)
