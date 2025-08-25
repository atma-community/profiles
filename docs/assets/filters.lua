function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

return {
  {
    CodeBlock = function (elem)
      if table.contains(elem.classes, "mermaid") then
        local pre_classes = elem.classes
        local html = string.format('<pre class="%s">%s</pre>',
          table.concat(pre_classes, ' '),
          elem.text:gsub("<", "&lt;"):gsub(">", "&gt;"))
        return pandoc.RawBlock('html', html)
      else
        return elem
      end
    end,
  }
}

