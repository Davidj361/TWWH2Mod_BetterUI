--  Copyright (C) 2020 David Jatczak <david.j.361@gmail.com>
--  
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.

--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.

--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <https://www.gnu.org/licenses/>.

local interface = {
}

local tsv = {

   headerRaw = "",
   header = {},
   rows = {},

}


function tsv:empty()
   self.headerRaw = ""
   self.header = {}
   self.rows = ""
end


function tsv:parseHeader(str)
   for v in str.gmatch(str, "[^\t]+") do
	  table.insert(self.header, v)
   end
end


function tsv:parseRow(str)
   local row = {}
   row.raw = str
   local i = 1
   for v in str.gmatch(str, "[^\t]+") do
	  row[ self.header[i] ] = tostring(v)
	  i = i+1
   end
   table.insert(self.rows, row)
end


function tsv:get(i, ind)
   local ret
   if ind then
	  ret = self.rows[i][ind]
   else
	  ret = self.rows[i]
   end
   return ret
end


function tsv:getRaw(i)
   local ret
   return self.rows[i].raw
end


function tsv:size()
   return #self.rows
end


function interface:readFile(textFile)
   local o = {}
   setmetatable(o, tsv)
   tsv.__index = tsv
   -- Check if file exists
   local file = io.open(textFile, "r")
   if not file then error("ftcsv: File not found at " .. textFile) end
   file:close()
   -- Take in data
   local lines = {}
   local firstLine = true
   for line in io.lines(textFile) do 
	  if firstLine then
		 self.headerRaw = line
		 self:parseHeader(line)
		 firstLine = false
	  else
		 self:parseRow(line)
	  end
   end
end


return interface
