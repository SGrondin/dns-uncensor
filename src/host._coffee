crypto = require "crypto"
url = require "url"
asyncReplace = require "async-replace"
settings = require "../settings"

getHash = (redisClient, host, clientIP, _) ->
	hash = (crypto.pseudoRandomBytes 16, _).toString "hex"
	keys = ["hostTunneling-"+hash, "xforwardedfor-"+hash]
	values = [host, clientIP]
	keys.forEach_ _, -1, (_, k, i) ->
		redisClient.set [k, values[i]], _
		redisClient.expire [k, settings.hostTunnelingCaching], _
	hash

redirectToHash = (res, hash, path) ->
	redirect = "https://"+hash+"."+settings.hostTunnelingDomain+path
	res.writeHead 302, {Location:redirect}
	res.end """<html><body>The unblock.us.org project<br /><br />Unblocked at <a href="#{redirect}">#{redirect}</a></body></html>"""

contentTypes = {
	"application/javascript", "application/xhtml+xml", "application/xml", "image/svg+xml", "text/css", "text/html", "text/javascript"
}
isAltered = (ct) -> contentTypes[ct]?

# This will probably need a lot of tweaking
# Creates something like (?:https://(?:[a-zA-Z0-9\-]+[.]{1})*?)?(?:(?:youtube[.]com)|(?:ggpht[.]com)|(?:ytimg[.]com)|(?:youtube-nocookie[.]com)|(?:youtu[.]be)
rDomains = new RegExp "(?:https://(?:[a-zA-Z0-9\-]+[.]{1})*?)?(?:"+("(?:"+a.replace(/[.]/g, "[.]")+")" for a of settings.hijacked).join("|")+")", "g"
redirectAllURLs = (str, redisClient, clientIP, currentDomain, currentHash, _) ->
	hashes = {currentDomain:currentHash}
	asyncReplace str, rDomains, ((found, f2, f3, _) ->
		parsed = url.parse found
		parsed.path = ""
		parsed.pathname = ""
		if not parsed.host? or not parsed.hostname?
			parsed.hostname = parsed.href
		parsed.host = null # Force the url module to use hostname+port
		if parsed.protocol? then parsed.protocol = "https"
		if hashes[parsed.hostname]?
			parsed.hostname = hashes[parsed.hostname]+"."+settings.hostTunnelingDomain
		else
			hash = getHash redisClient, parsed.hostname, clientIP, _
			hashes[parsed.hostname] = hash
			parsed.hostname = hash+"."+settings.hostTunnelingDomain
		url.format parsed
	), _

module.exports = {getHash, redirectToHash, isAltered, redirectAllURLs}