local Filter = require("trouble.filter")

local M = {}

---@type table<string, trouble.Sorter>
M.sorters = {
  pos = function(obj)
    -- Use large multipliers for higher priority fields to ensure their precedence in sorting
    local primaryScore = obj.pos[1] * 1000000 + obj.pos[2] * 1000
    local secondaryScore = obj.end_pos[1] * 1000000 + obj.end_pos[2] * 1000

    return primaryScore + secondaryScore
  end,
}

---@param items trouble.Item[]
---@param view trouble.View
---@param opts? trouble.Sort
function M.sort(items, opts, view)
  if not opts or #opts == 0 then
    return items
  end

  local keys = {} ---@type table<trouble.Item, any[]>
  local desc = {} ---@type boolean[]

  -- pre-compute fields
  local fields = {} ---@type {sorter?:trouble.Sorter, field?:string, filter?:trouble.Filter}[]
  for f, field in ipairs(opts) do
    if type(field) == "function" then
      ---@cast field trouble.Sorter
      fields[f] = { sorter = field }
    elseif type(field) == "table" and field.field then
      ---@cast field {field:string, desc?:boolean}
      local sorter = view.opts.sorters[field.field] or M.sorters[field.field]
      if sorter then
        fields[f] = { sorter = sorter }
      else
        fields[f] = { field = field.field }
      end
      desc[f] = field.desc
    elseif type(field) == "table" then
      fields[f] = { filter = field }
    else
      error("invalid sort field: " .. vim.inspect(field))
    end
  end

  -- pre-compute keys
  for _, item in ipairs(items) do
    local item_keys = {} ---@type any[]
    for f, field in ipairs(fields) do
      local key = nil
      if field.sorter then
        key = field.sorter(item)
      elseif field.field then
        ---@diagnostic disable-next-line: no-unknown
        key = item[field.field]
      elseif field.filter then
        key = Filter.is(item, field.filter, view)
      end
      if type(key) == "boolean" then
        key = key and 0 or 1
      end
      item_keys[f] = key
    end
    keys[item] = item_keys
  end

  -- sort items
  table.sort(items, function(a, b)
    local ka = keys[a]
    local kb = keys[b]
    for i = 1, #ka do
      local fa = ka[i]
      local fb = kb[i]
      if fa ~= fb then
        if desc[i] then
          return fa > fb
        else
          return fa < fb
        end
      end
    end
    return false
  end)
  return items
end

return M
