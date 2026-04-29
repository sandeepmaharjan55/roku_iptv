sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    requestUrl = m.top.url
    if requestUrl = invalid or requestUrl = "" then
        requestUrl = "https://iptv-org.github.io/iptv/languages/hin.m3u"
    end if

    content = CreateObject("roSGNode", "ContentNode")
    m.top.errorMessage = ""

    urls = buildUrlCandidates(requestUrl)
    rawData = ""
    lastError = ""

    for each candidate in urls
        rawData = fetchTextWithTimeout(candidate, 15000)
        if rawData <> invalid and rawData <> "" then
            exit for
        else
            if m.fetchError <> invalid and m.fetchError <> "" then
                lastError = m.fetchError
            end if
        end if
    end for

    if rawData = invalid or rawData = "" then
        rawData = ReadAsciiFile("pkg:/data/fallback.m3u")
        if rawData <> invalid and rawData <> "" then
            lastError = "Remote Hindi IPTV playlist could not be downloaded. Showing packaged fallback data instead."
        end if
    end if

    if rawData = invalid or rawData = "" then
        m.top.content = content
        m.top.errorMessage = "Failed to fetch Hindi IPTV playlist. Check Roku network access to iptv-org.github.io."
        return
    end if

    content = parseM3UToContent(rawData)
    m.top.content = content

    if content.getChildCount() = 0 then
        if lastError = invalid or lastError = "" then
            lastError = "Playlist downloaded, but no channel entries were parsed."
        end if
    end if

    m.top.errorMessage = lastError
end sub

function buildUrlCandidates(requestUrl)
    urls = []
    if requestUrl <> invalid and requestUrl <> "" then
        urls.Push(requestUrl)
    end if

    pagesUrl = "https://iptv-org.github.io/iptv/languages/hin.m3u"
    rawUrl = "https://raw.githubusercontent.com/iptv-org/iptv/master/languages/hin.m3u"

    if requestUrl <> pagesUrl then
        urls.Push(pagesUrl)
    end if
    if requestUrl <> rawUrl then
        urls.Push(rawUrl)
    end if

    return urls
end function

function fetchTextWithTimeout(url, timeoutMs)
    m.fetchError = ""

    port = CreateObject("roMessagePort")
    transfer = CreateObject("roUrlTransfer")
    transfer.SetMessagePort(port)
    transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.InitClientCertificates()
    transfer.SetUrl(url)

    ok = transfer.AsyncGetToString()
    if ok = false then
        m.fetchError = "Could not start request for " + url
        return ""
    end if

    elapsed = 0
    stepMs = 500

    while elapsed < timeoutMs
        msg = wait(stepMs, port)
        if msg <> invalid then
            msgType = type(msg)
            if msgType = "roUrlEvent" then
                code = msg.GetResponseCode()
                if code >= 200 and code <= 299 then
                    result = msg.GetString()
                    if result <> invalid and result <> "" then
                        return result
                    else
                        m.fetchError = "Empty response from " + url
                        return ""
                    end if
                else
                    m.fetchError = "HTTP " + itostr(code) + " while fetching " + url
                    return ""
                end if
            end if
        end if
        elapsed = elapsed + stepMs
    end while

    transfer.AsyncCancel()
    m.fetchError = "Timed out while fetching " + url
    return ""
end function

function parseM3UToContent(data)
    content = CreateObject("roSGNode", "ContentNode")
    lines = splitToLines(data)
    currentTitle = ""
    currentId = ""
    currentLogo = ""
    currentGroup = ""

    for each rawLine in lines
        line = trimText(rawLine)
        if line <> "" then
            firstChar = Left(line, 1)
            if Left(line, 7) = "#EXTINF" then
                currentTitle = parseTitle(line)
                currentId = extractQuotedValue(line, "tvg-id")
                currentLogo = extractQuotedValue(line, "tvg-logo")
                currentGroup = extractQuotedValue(line, "group-title")
            else if firstChar <> "#" then
                item = content.CreateChild("ContentNode")
                if currentTitle = invalid or currentTitle = "" then
                    item.title = "Untitled Channel"
                else
                    item.title = currentTitle
                end if
                item.addFields({
                    id: currentId
                    logo: currentLogo
                    group: currentGroup
                    url: line
                })
                item.shortDescriptionLine1 = item.title
                if currentGroup <> invalid and currentGroup <> "" then
                    item.shortDescriptionLine2 = currentGroup
                else
                    item.shortDescriptionLine2 = "Hindi"
                end if
                item.hdPosterUrl = currentLogo
                currentTitle = ""
                currentId = ""
                currentLogo = ""
                currentGroup = ""
            end if
        end if
    end for

    return content
end function

function parseTitle(line)
    commaPos = Instr(1, line, ",")
    if commaPos <= 0 then
        return ""
    end if
    return trimText(Mid(line, commaPos + 1))
end function

function extractQuotedValue(line, key)
    quote = Chr(34)
    prefix = key + "=" + quote
    startPos = Instr(1, line, prefix)
    if startPos <= 0 then
        return ""
    end if

    valueStart = startPos + Len(prefix)
    remainder = Mid(line, valueStart)
    quotePos = Instr(1, remainder, quote)
    if quotePos <= 0 then
        return ""
    end if

    return Left(remainder, quotePos - 1)
end function

function splitToLines(data)
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

function trimText(value)
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

function isBlankChar(ch)
    if ch = " " then return true
    if ch = Chr(9) then return true
    return false
end function
