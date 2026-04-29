sub init()
    m.top.backgroundURI = ""
    m.top.playlistUrl = "https://iptv-org.github.io/iptv/languages/hin.m3u"
    m.kantipurTitle = "Kantipur TV"
    m.kantipurId = "KantipurTV.np"
    m.kantipurLogo = "https://i.imgur.com/HEVo2Gc.png"
    m.kantipurGroup = "general"
    m.kantipurUrl = "https://ktvhdsg.ekantipur.com:8443/high_quality_85840165/hd/playlist.m3u8"

    m.titleLabel = m.top.findNode("titleLabel")
    m.subtitleLabel = m.top.findNode("subtitleLabel")
    m.searchLabel = m.top.findNode("searchLabel")
    m.channelList = m.top.findNode("channelList")
    m.logoPoster = m.top.findNode("logoPoster")
    m.heroLabel = m.top.findNode("heroLabel")
    m.heroSubLabel = m.top.findNode("heroSubLabel")
    m.channelName = m.top.findNode("channelName")
    m.groupChip = m.top.findNode("groupChip")
    m.groupChipText = m.top.findNode("groupChipText")
    m.favoriteChip = m.top.findNode("favoriteChip")
    m.favoriteChipText = m.top.findNode("favoriteChipText")
    m.channelMeta = m.top.findNode("channelMeta")
    m.helpText = m.top.findNode("helpText")
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.playlistTask = m.top.findNode("playlistTask")
    m.favoritesTask = m.top.findNode("favoritesTask")

    m.browserNodeIds = ["bg", "titleLabel", "subtitleLabel", "searchBg", "searchLabel", "channelList", "logoPoster", "heroLabel", "heroSubLabel", "channelName", "groupChip", "groupChipText", "favoriteChip", "favoriteChipText", "channelMeta", "helpText"]

    m.channels = []
    m.filteredChannels = []
    m.favoriteMap = {}
    m.supportedOnly = true
    m.favoritesOnly = false
    m.searchQuery = ""
    m.searchDialog = invalid
    m.categories = ["All categories", "Favorites"]
    m.selectedCategoryIndex = 1

    m.channelList.observeField("itemSelected", "onItemSelected")
    m.channelList.observeField("itemFocused", "onItemFocused")
    m.videoPlayer.observeField("state", "onVideoStateChanged")
    m.playlistTask.observeField("content", "onPlaylistLoaded")
    m.playlistTask.observeField("state", "onTaskStateChanged")
    m.playlistTask.observeField("errorMessage", "onPlaylistError")
    m.favoritesTask.observeField("result", "onFavoritesLoaded")

    m.channelList.itemComponentName = "ChannelListItem"
    updateSearchLabel()
    loadFavorites()
    loadPlaylist()
end sub

sub loadFavorites()
    m.favoritesTask.mode = "load"
    m.favoritesTask.control = "RUN"
end sub

sub saveFavorites()
    m.favoritesTask.mode = "save"
    m.favoritesTask.data = serializeFavorites()
    m.favoritesTask.control = "RUN"
end sub

sub loadPlaylist()
    m.subtitleLabel.text = "Loading Hindi IPTV playlist..."
    m.heroLabel.text = "Loading channels"
    m.heroSubLabel.text = "Fetching the Hindi IPTV playlist and preparing the channel list for Roku."
    m.channelMeta.text = "Please wait while the playlist is downloaded and parsed."
    m.playlistTask.url = m.top.playlistUrl
    m.playlistTask.control = "RUN"
end sub

sub onFavoritesLoaded()
    if m.favoritesTask.mode <> "load" then return
    m.favoriteMap = parseFavorites(m.favoritesTask.result)
    ensureKantipurFavorite()
    if m.channels <> invalid and m.channels.count() > 0 then
        ensureKantipurChannelPresent()
        applyFilter()
    end if
end sub

sub onPlaylistLoaded()
    content = m.playlistTask.content
    if content = invalid or content.getChildCount() = 0 then
        m.subtitleLabel.text = "No channels found in playlist"
        m.heroLabel.text = "Nothing found"
        m.heroSubLabel.text = "The playlist loaded, but no playable entries were parsed."
        return
    end if

    m.channels = []
    for i = 0 to content.getChildCount() - 1
        node = content.getChild(i)
        item = {}
        item.title = node.title
        item.id = node.id
        item.logo = node.logo
        item.group = node.group
        item.url = node.url
        m.channels.push(item)
    end for

    ensureKantipurChannelPresent()
    buildCategories()
    applyFilter()
end sub

sub ensureKantipurFavorite()
    if m.favoriteMap = invalid then
        m.favoriteMap = {}
    end if
    if m.kantipurUrl <> invalid and m.kantipurUrl <> "" then
        m.favoriteMap[m.kantipurUrl] = m.kantipurTitle
        saveFavorites()
    end if
end sub

sub ensureKantipurChannelPresent()
    if m.channels = invalid then
        m.channels = []
    end if

    for each channel in m.channels
        if channel <> invalid and channel.url = m.kantipurUrl then
            return
        end if
    end for

    item = {}
    item.title = m.kantipurTitle
    item.id = m.kantipurId
    item.logo = m.kantipurLogo
    item.group = m.kantipurGroup
    item.url = m.kantipurUrl
    m.channels.push(item)
end sub

sub buildCategories()
    cats = ["All categories", "Favorites"]
    for each channel in m.channels
        grp = normalizeCategory(channel.group)
        exists = false
        for each c in cats
            if c = grp then
                exists = true
                exit for
            end if
        end for
        if exists = false then
            cats.push(grp)
        end if
    end for
    m.categories = cats
    if m.selectedCategoryIndex < 0 then
        m.selectedCategoryIndex = 0
    end if
    if m.selectedCategoryIndex >= m.categories.count() then
        m.selectedCategoryIndex = 0
    end if
end sub

sub onTaskStateChanged()
    if m.playlistTask.state = "stop" and (m.channels = invalid or m.channels.count() = 0) then
        if m.playlistTask.errorMessage = invalid or m.playlistTask.errorMessage = "" then
            m.subtitleLabel.text = "Playlist request stopped"
            m.heroLabel.text = "No playlist data received"
            m.heroSubLabel.text = "The remote source did not return usable data. Try again or check network access on the Roku device."
            m.channelMeta.text = "The task stopped without returning channels. This usually means the remote host was blocked, unreachable, or too slow for the device."
        end if
    end if
end sub

sub onPlaylistError()
    if m.playlistTask.errorMessage <> invalid and m.playlistTask.errorMessage <> "" then
        m.subtitleLabel.text = "Playlist note"
        m.heroLabel.text = "Playlist status"
        m.heroSubLabel.text = "The app loaded the playlist with a fallback or additional note."
        m.channelMeta.text = m.playlistTask.errorMessage
    end if
end sub

sub applyFilter()
    focusedUrl = ""
    idx = m.channelList.itemFocused
    if idx >= 0 and idx < m.filteredChannels.count() then
        currentItem = m.filteredChannels[idx]
        if currentItem <> invalid and currentItem.url <> invalid then
            focusedUrl = currentItem.url
        end if
    end if
    applyFilterPreservingUrl(focusedUrl)
end sub

sub applyFilterPreservingUrl(focusedUrl as string)
    filtered = []
    query = lcase(m.searchQuery)
    activeCategory = getCurrentCategory()
    restoreIndex = 0

    for each channel in m.channels
        includeItem = true

        if m.supportedOnly = true and isProbablySupported(channel.url) = false then
            includeItem = false
        end if

        if includeItem = true and m.favoritesOnly = true and isFavorite(channel.url) = false then
            includeItem = false
        end if

        if includeItem = true and activeCategory = "Favorites" then
            if isFavorite(channel.url) = false then
                includeItem = false
            end if
        else if includeItem = true and activeCategory <> "All categories" then
            grp = normalizeCategory(channel.group)
            if grp <> activeCategory then
                includeItem = false
            end if
        end if

        if includeItem = true and query <> "" then
            hayTitle = lcase(safeText(channel.title))
            hayGroup = lcase(safeText(channel.group))
            if instr(1, hayTitle, query) = 0 and instr(1, hayGroup, query) = 0 then
                includeItem = false
            end if
        end if

        if includeItem = true then
            if focusedUrl <> "" and channel.url = focusedUrl then
                restoreIndex = filtered.count()
            end if
            filtered.push(channel)
        end if
    end for

    filtered = prioritizeKantipurInFavorites(filtered, activeCategory)
    m.filteredChannels = filtered
    updateSearchLabel()

    if filtered.count() = 0 then
        m.subtitleLabel.text = "No channels match the current view"
        m.heroLabel.text = "No matching channels"
        m.heroSubLabel.text = "Change search text, category, favorites view, or stream filter to see more channels."
        m.channelMeta.text = "Try Fast Forward for search, Left or Right to change category, Rewind to clear search, Play/Pause for favorites view, or Instant Replay for the Roku-friendly stream filter."
        buildListContent([])
        return
    end if

    if restoreIndex < 0 then
        restoreIndex = 0
    end if
    if restoreIndex >= filtered.count() then
        restoreIndex = filtered.count() - 1
    end if

    m.subtitleLabel.text = filtered.count().toStr() + " channels available"
    buildListContent(filtered)
    updateDetails(restoreIndex)
    m.channelList.jumpToItem = restoreIndex
    m.channelList.setFocus(true)
end sub

sub updateSearchLabel()
    parts = []
    if m.searchQuery <> "" then
        parts.push("Search: " + m.searchQuery)
    else
        parts.push("Search: All channels")
    end if

    parts.push("Category: " + getCurrentCategory())

    if m.favoritesOnly then
        parts.push("View: Favorites")
    else
        parts.push("View: All")
    end if

    if m.supportedOnly then
        parts.push("Format: Roku-friendly")
    else
        parts.push("Format: All")
    end if

    m.searchLabel.text = joinStrings(parts, "   |   ")
end sub


function prioritizeKantipurInFavorites(items as object, activeCategory as string) as object
    shouldPrioritize = false
    if m.favoritesOnly = true then
        shouldPrioritize = true
    end if
    if activeCategory = "Favorites" then
        shouldPrioritize = true
    end if

    if shouldPrioritize = false then
        return items
    end if

    if items = invalid then
        return []
    end if

    prioritized = []
    otherItems = []

    for each item in items
        if item <> invalid and item.url = m.kantipurUrl and isFavorite(item.url) then
            prioritized.push(item)
        else
            otherItems.push(item)
        end if
    end for

    for each item in otherItems
        prioritized.push(item)
    end for

    return prioritized
end function

function getCurrentCategory()
    if m.categories = invalid then
        return "All categories"
    end if
    if m.selectedCategoryIndex < 0 then
        return "All categories"
    end if
    if m.selectedCategoryIndex >= m.categories.count() then
        return "All categories"
    end if
    return m.categories[m.selectedCategoryIndex]
end function

sub changeCategory(direction)
    if m.categories = invalid then
        return
    end if
    if m.categories.count() = 0 then
        return
    end if
    m.selectedCategoryIndex = m.selectedCategoryIndex + direction
    if m.selectedCategoryIndex < 0 then
        m.selectedCategoryIndex = m.categories.count() - 1
    end if
    if m.selectedCategoryIndex >= m.categories.count() then
        m.selectedCategoryIndex = 0
    end if
    applyFilter()
end sub

function normalizeCategory(value)
    txt = trimText(value)
    if txt = "" then
        return "Other"
    end if
    return txt
end function

function isProbablySupported(url as dynamic) as boolean
    if url = invalid then return false
    u = lcase(url)
    if instr(1, u, ".m3u8") > 0 then return true
    if instr(1, u, ".mpd") > 0 then return true
    if instr(1, u, ".mp4") > 0 then return true
    if instr(1, u, "format=mpd") > 0 then return true
    if instr(1, u, "format=m3u8") > 0 then return true
    return false
end function

sub buildListContent(items as object)
    content = CreateObject("roSGNode", "ContentNode")
    for each item in items
        row = content.createChild("ContentNode")
        row.title = item.title
        row.shortDescriptionLine1 = item.title
        row.shortDescriptionLine2 = normalizeCategory(item.group)
        row.hdPosterUrl = item.logo
        row.addFields({
            isFavorite: isFavorite(item.url)
        })
    end for
    m.channelList.content = content
end sub

sub onItemFocused()
    idx = m.channelList.itemFocused
    if idx >= 0 and idx < m.filteredChannels.count() then
        updateDetails(idx)
    end if
end sub

sub onItemSelected()
    idx = m.channelList.itemSelected
    if idx < 0 or idx >= m.filteredChannels.count() then return
    playChannel(idx)
end sub

sub updateDetails(idx as integer)
    if idx < 0 or idx >= m.filteredChannels.count() then return
    item = m.filteredChannels[idx]

    m.channelName.text = safeText(item.title)
    m.heroLabel.text = safeText(item.title)
    m.heroSubLabel.text = "Press OK to play. Press Options to save or remove this channel from favorites."

    m.groupChipText.text = normalizeCategory(item.group)

    if isFavorite(item.url) then
        m.favoriteChip.color = "0x3B2F1FFF"
        m.favoriteChipText.text = "Saved"
    else
        m.favoriteChip.color = "0x1F2A38FF"
        m.favoriteChipText.text = "Not saved"
    end if

    meta = []
    meta.push("Category: " + normalizeCategory(item.group))
    if item.id <> invalid and item.id <> "" then
        meta.push("Channel ID: " + item.id)
    end if

    if item.logo <> invalid and item.logo <> "" then
        meta.push("Logo: available")
    else
        meta.push("Logo: not available")
    end if

    if isFavorite(item.url) then
        meta.push("Favorite: yes")
    else
        meta.push("Favorite: no")
    end if

    fmt = detectStreamFormat(item.url)
    if fmt <> "" then
        meta.push("Detected format: " + ucase(fmt))
    else
        meta.push("Detected format: unknown")
    end if

    meta.push("Stream URL: " + item.url)
    m.channelMeta.text = joinStrings(meta, chr(10))

    if item.logo <> invalid and item.logo <> "" then
        m.logoPoster.uri = item.logo
    else
        m.logoPoster.uri = ""
    end if
end sub

sub setBrowserUiVisible(isVisible as boolean)
    if m.browserNodeIds = invalid then
        return
    end if
    for each nodeId in m.browserNodeIds
        node = m.top.findNode(nodeId)
        if node <> invalid then
            node.visible = isVisible
        end if
    end for
end sub

sub playChannel(idx as integer)
    item = m.filteredChannels[idx]
    content = CreateObject("roSGNode", "ContentNode")
    content.url = item.url
    content.streamFormat = detectStreamFormat(item.url)
    content.title = item.title

    if content.streamFormat = "" then
        m.subtitleLabel.text = "Unsupported or unknown stream format"
        m.heroSubLabel.text = "This entry does not look like a Roku-friendly HLS, DASH, or MP4 stream."
        return
    end if

    setBrowserUiVisible(false)
    m.videoPlayer.content = content
    m.videoPlayer.visible = true
    m.videoPlayer.translation = [0, 0]
    m.videoPlayer.width = 1920
    m.videoPlayer.height = 1080
    m.videoPlayer.setFocus(true)
    m.videoPlayer.control = "play"
    m.subtitleLabel.text = "Playing: " + item.title
    m.heroSubLabel.text = "Playback in progress. Press Back to return to the channel browser."
end sub

function detectStreamFormat(url as string) as string
    u = lcase(url)
    if instr(1, u, ".m3u8") > 0 then return "hls"
    if instr(1, u, ".mpd") > 0 then return "dash"
    if right(u, 4) = ".mp4" then return "mp4"
    if instr(1, u, "format=m3u8") > 0 then return "hls"
    if instr(1, u, "format=mpd") > 0 then return "dash"
    return ""
end function

sub onVideoStateChanged()
    state = m.videoPlayer.state
    if state = "error" then
        setBrowserUiVisible(true)
        m.subtitleLabel.text = "Playback failed on Roku for this stream"
        m.heroSubLabel.text = "The stream exists, but Roku could not play it. The source may be dead, blocked, or unsupported."
        m.videoPlayer.visible = false
        m.channelList.setFocus(true)
    else if state = "finished" or state = "stopped" then
        setBrowserUiVisible(true)
        m.videoPlayer.visible = false
        m.channelList.setFocus(true)
        m.subtitleLabel.text = "Playback stopped"
    end if
end sub

sub openSearchDialog()
    dialog = CreateObject("roSGNode", "KeyboardDialog")
    dialog.title = "Search channels"
    dialog.message = "Type a channel or group name"
    dialog.buttons = ["Apply", "Clear", "Cancel"]
    dialog.text = m.searchQuery
    dialog.observeField("buttonSelected", "onSearchDialogButton")
    m.searchDialog = dialog
    m.top.dialog = dialog
end sub

sub onSearchDialogButton()
    if m.searchDialog = invalid then return
    idx = m.searchDialog.buttonSelected

    if idx = 0 then
        if m.searchDialog.text <> invalid then
            m.searchQuery = trimText(m.searchDialog.text)
        else
            m.searchQuery = ""
        end if
        applyFilter()
    else if idx = 1 then
        m.searchQuery = ""
        applyFilter()
    end if

    m.top.dialog = invalid
    m.searchDialog = invalid
    buildCategories()
    m.selectedCategoryIndex = 0
    m.channelList.setFocus(true)
end sub

sub toggleFavoriteForFocused()
    idx = m.channelList.itemFocused
    if idx < 0 or idx >= m.filteredChannels.count() then return

    item = m.filteredChannels[idx]
    url = item.url
    if url = invalid or url = "" then return

    keepUrl = url

    if isFavorite(url) then
        m.favoriteMap.Delete(url)
        m.subtitleLabel.text = "Removed from favorites: " + safeText(item.title)
    else
        m.favoriteMap[url] = safeText(item.title)
        m.subtitleLabel.text = "Saved to favorites: " + safeText(item.title)
    end if

    saveFavorites()
    applyFilterPreservingUrl(keepUrl)
end sub

function isFavorite(url as dynamic) as boolean
    if url = invalid then return false
    if m.favoriteMap = invalid then return false
    return m.favoriteMap.doesExist(url)
end function

function serializeFavorites() as string
    if m.favoriteMap = invalid then return ""
    keys = m.favoriteMap.keys()
    result = ""
    for i = 0 to keys.count() - 1
        result = result + keys[i]
        if i < keys.count() - 1 then
            result = result + Chr(10)
        end if
    end for
    return result
end function

function parseFavorites(data as dynamic) as object
    result = {}
    if data = invalid or data = "" then return result
    lines = splitToLines(data)
    for each line in lines
        value = trimText(line)
        if value <> "" then
            result[value] = "1"
        end if
    end for
    return result
end function

function splitToLines(data as string) as object
    lines = []
    current = ""
    length = Len(data)
    i = 1
    while i <= length
        ch = Mid(data, i, 1)
        if ch = Chr(10) then
            lines.Push(current)
            current = ""
        else if ch <> Chr(13) then
            current = current + ch
        end if
        i = i + 1
    end while
    lines.Push(current)
    return lines
end function

function trimText(value as dynamic) as string
    if value = invalid then
        return ""
    end if

    startPos = 1
    endPos = Len(value)

    while startPos <= endPos and isBlankChar(Mid(value, startPos, 1))
        startPos = startPos + 1
    end while

    while endPos >= startPos and isBlankChar(Mid(value, endPos, 1))
        endPos = endPos - 1
    end while

    if endPos < startPos then
        return ""
    end if

    return Mid(value, startPos, endPos - startPos + 1)
end function

function isBlankChar(ch as string) as boolean
    if ch = " " then return true
    if ch = Chr(9) then return true
    return false
end function

function safeText(value as dynamic) as string
    if value = invalid then return ""
    return value
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if press = false then return false

    if key = "options" and m.videoPlayer.visible = false then
        toggleFavoriteForFocused()
        return true
    end if

    if key = "play" and m.videoPlayer.visible = false then
        m.favoritesOnly = not m.favoritesOnly
        applyFilter()
        return true
    end if

    if key = "left" and m.videoPlayer.visible = false then
        changeCategory(-1)
        return true
    end if

    if key = "right" and m.videoPlayer.visible = false then
        changeCategory(1)
        return true
    end if

    if key = "fwd" and m.videoPlayer.visible = false then
        openSearchDialog()
        return true
    end if

    if key = "rev" and m.videoPlayer.visible = false then
        if m.searchQuery <> "" then
            m.searchQuery = ""
            applyFilter()
            return true
        end if
    end if

    if key = "instantreplay" and m.videoPlayer.visible = false then
        m.supportedOnly = not m.supportedOnly
        applyFilter()
        return true
    end if

    if key = "back" and m.videoPlayer.visible = true then
        m.videoPlayer.control = "stop"
        setBrowserUiVisible(true)
        m.videoPlayer.visible = false
        m.channelList.setFocus(true)
        m.subtitleLabel.text = "Playback stopped"
        return true
    end if

    return false
end function

function joinStrings(items as object, separator as string) as string
    result = ""
    for i = 0 to items.count() - 1
        result = result + items[i]
        if i < items.count() - 1 then result = result + separator
    end for
    return result
end function
