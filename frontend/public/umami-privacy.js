(function () {
  const dynamicRoutes = [
    [/^\/players\/[^/]+\/?$/, '/players/:id'],
    [/^\/games\/[^/]+\/?$/, '/games/:id'],
    [/^\/teams\/[^/]+\/?$/, '/teams/:id'],
    [/^\/saved\/[^/]+\/?$/, '/saved/:id'],
    [/^\/opponent-reports\/[^/]+\/?$/, '/opponent-reports/:id'],
    [/^\/lineup-scenarios\/[^/]+\/?$/, '/lineup-scenarios/:id'],
  ]

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

      return {
        ...payload,
        url: matchingRoute ? matchingRoute[1] : pathname,
      }
    } catch (_error) {
      // Privacy-first failure: do not send a URL we could not inspect.
      return false
    }
  }
})()