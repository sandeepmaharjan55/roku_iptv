sub init()
    m.bg = m.top.findNode("bg")
    m.accent = m.top.findNode("accent")
    m.thumb = m.top.findNode("thumb")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.cta = m.top.findNode("cta")
    m.favBadgeBg = m.top.findNode("favBadgeBg")
    m.favBadge = m.top.findNode("favBadge")
    m.top.observeField("focusPercent", "onFocusChanged")
end sub

sub showContent()
    item = m.top.itemContent
    if item <> invalid then
        m.title.text = item.shortDescriptionLine1
        m.subtitle.text = item.shortDescriptionLine2
        if item.hdPosterUrl <> invalid and item.hdPosterUrl <> "" then
            m.thumb.uri = item.hdPosterUrl
        else
            m.thumb.uri = ""
        end if

        isFavorite = false
        if item.isFavorite <> invalid and item.isFavorite = true then
            isFavorite = true
        end if
        m.favBadge.visible = isFavorite
        m.favBadgeBg.visible = isFavorite
    end if
end sub

sub onFocusChanged()
    if m.top.focusPercent > 0 then
        m.bg.color = "0x25364AFF"
        m.accent.color = "0x67A8F0FF"
        m.cta.color = "0xD9E7F5FF"
    else
        m.bg.color = "0x182330FF"
        m.accent.color = "0x182330FF"
        m.cta.color = "0x6D8194FF"
    end if
end sub
