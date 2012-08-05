-- tester.lua -- Test switch operation by post-processing trace files.
-- Copright 2012 Snabb GmbH

module("tester",package.seeall)

local ffi  = require("ffi")
local pcap = require("pcap")
local C    = ffi.C

if #arg ~= 1 then
   print "Usage: tester <pcapfile>"
   print ""
   print "Test that the switching behaviour in pcapfile is correct."
   return
end

local file = io.open(arg[1], "r")
local pcap_file   = ffi.new("struct pcap_file")
local pcap_record = ffi.new("struct pcap_record")
local pcap_extra  = ffi.new("struct pcap_record_extra")

print("filename = " .. arg[1] .. " " .. #arg)
print(ffi.cast("struct pcap_file *", file:read(ffi.sizeof("struct pcap_file"))))

function main ()
   local input, outputs = nil, {}
   for packet, header, extra in pcap.records(arg[1]) do
      if extra.flags == 0 then
	 if input ~= nil then
	    check(input, outputs)
	 end
	 input = {port = extra.port_id, packet = packet}
	 outputs = {}
      else
	 table.insert(outputs, {port = extra.port_id, packet = packet})
      end
--      print(#packet, header, extra, extra.port_id, extra.flags)
   end
end

local success = 0
local failed  = 0

function check (input, outputs)
   check_loop(input, outputs)
   check_drop(input, outputs)
   check_forward(input, outputs)
   check_flood(input, outputs)
   success = success + 1
end

function check_loop (input, outputs)
   for _,output in ipairs(outputs) do
      if input.port == output.port then
	 fail(input, outputs, "Loop error on port " .. input.port)
      end
   end
end

function check_drop (input, outputs)
   if #outputs == 0 then
      fail(input, outputs, "Dropped packet from " .. input.port)
   end
end

local fdb = {}

function check_forward (input, outputs)
   local src = string.sub(input.packet, 1, 6)
   local dst = string.sub(input.packet, 7, 12)
   if fdb[dst] then
      local found = false
      for _,output in ipairs(outputs) do
	 if output.port == fdb[dst] then
	    found = true
	    break
	 end
      end
      if found == false then
	 fail(input, outputs, "Forwarding failed, expected to " .. fdb[dst])
      end
   end
   fdb[src] = input.port
end

local ports = {}

function check_flood (input, outputs)
   local multicast = string.byte(input.packet, 7) < 0x80
   if multicast and #outputs < #ports then
      fail(input, outputs, "Ethernet multicast not sent to enough ports")
   end
end

function fail (input, outputs, reason)
   print(reason)
   failed = failed + 1
end

main()

if failed == 0 then
   print("Success! " .. success .. " test(s) passed.")
else
   print("Failed! " .. failed .. "/" .. (success + failed) .. " tests failed.")
   os.exit(1)
end

