sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    section = CreateObject("roRegistrySection", "HindiIPTV")
    mode = m.top.mode

    if mode = "save" then
        value = m.top.data
        if value = invalid then
            value = ""
        end if
        section.Write("favorites", value)
        section.Flush()
        m.top.result = value
        return
    end if

    saved = section.Read("favorites")
    if saved = invalid then saved = ""
    m.top.result = saved
end sub
