(function () {
  const eventProperties = Object.create(null)
  const dynamicRoutes = [
    [/^\/players\/[^/]+\/?$/, '/players/:id'],
    [/^\/games\/[^/]+\/?$/, '/games/:id'],
    [/^\/teams\/[^/]+\/?$/, '/teams/:id'],
    [/^\/saved\/[^/]+\/?$/, '/saved/:id'],
    [/^\/opponent-reports\/[^/]+\/?$/, '/opponent-reports/:id'],
    [/^\/lineup-scenarios\/[^/]+\/?$/, '/lineup-scenarios/:id'],
  ]

  window.ninelensTrackEvent = function (name, data) {
    const key = `${name}:${data.mlb_id ?? ''}`
    eventProperties[key] = { ...(eventProperties[key] || {}), ...data }
    window.umami?.track?.(name, data)
  }

  window.ninelensUmamiBeforeSend = function (_type, payload) {
    if (!payload || typeof payload.url !== 'string') {
      return false
    }

    try {
      const url = new URL(payload.url, window.location.origin)
      const pathname = url.pathname.replace(/\/+$/, '') || '/'

      const matchingRoute = dynamicRoutes.find(([pattern]) =>
        pattern.test(pathname),
      )

      const key = `${payload.name || ''}:${payload.data?.mlb_id ?? ''}`
      const eventData = eventProperties[key]
      delete eventProperties[key]

      return {
        ...payload,
        ...(eventData ? { data: { ...(payload.data || {}), ...eventData } } : {}),
        url: matchingRoute ? matchingRoute[1] : pathname,
      }
    } catch (_error) {
      // Privacy-first failure: do not send a URL we could not inspect.
      return false
    }
  }
})()
