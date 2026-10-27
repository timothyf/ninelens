import type { Context } from "@netlify/functions"

const MLB_ORIGIN = "https://statsapi.mlb.com"
const TOKEN_HEADER = "x-ninelens-relay-token"
const MAX_UPSTREAM_LENGTH = 8_192
const ALLOWED_PATHS = [
  /^\/api\/v1\/schedule(?:\/games\/?)?$/,
  /^\/api\/v1\/game\/\d+\/boxscore$/,
  /^\/api\/v1\.1\/game\/\d+\/feed\/live$/,
  /^\/api\/v1\/teams\/stats$/,
  /^\/api\/v1\/teams\/\d+\/roster$/,
  /^\/api\/v1\/people(?:\/\d+)?$/,
  /^\/api\/v1\/people\/\d+\/stats$/,
  /^\/api\/v1\/awards\/(?:ALMVP|NLMVP|ALCY|NLCY|ALGG|NLGG)\/recipients$/,
  /^\/api\/v1\/standings$/,
  /^\/api\/v1\/transactions$/,
]

type RelayDependencies = {
  fetchImpl?: typeof fetch
  getSecret: () => string | undefined
}

function jsonResponse(status: number, message: string) {
  return Response.json({ message }, {
    status,
    headers: {
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  })
}

async function digest(value: string) {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value)))
}

async function tokensMatch(provided: string | null, expected: string | undefined) {
  if (!provided || !expected) return false

  const [providedDigest, expectedDigest] = await Promise.all([digest(provided), digest(expected)])
  let difference = providedDigest.length ^ expectedDigest.length
  for (let index = 0; index < expectedDigest.length; index += 1) {
    difference |= providedDigest[index] ^ expectedDigest[index]
  }
  return difference === 0
}

function allowedUpstream(value: string | null) {
  if (!value || value.length > MAX_UPSTREAM_LENGTH || !value.startsWith("/") || value.startsWith("//")) return null

  const upstream = new URL(value, MLB_ORIGIN)
  if (upstream.origin !== MLB_ORIGIN) return null
  if (!ALLOWED_PATHS.some((pattern) => pattern.test(upstream.pathname))) return null
  return upstream
}

export function createMlbRelayHandler({ fetchImpl = fetch, getSecret }: RelayDependencies) {
  return async (request: Request, context?: Context) => {
    if (request.method !== "GET") return jsonResponse(405, "Method not allowed")

    const expectedToken = getSecret()
    if (!expectedToken) {
      console.error(JSON.stringify({ requestId: context?.requestId, relayAuthConfigured: false }))
      return jsonResponse(503, "Relay authentication is not configured")
    }

    const providedToken = request.headers.get(TOKEN_HEADER)
    const authorized = await tokensMatch(providedToken, expectedToken)
    if (!authorized) {
      console.warn(JSON.stringify({
        requestId: context?.requestId,
        relayAuthConfigured: true,
        relayTokenProvided: Boolean(providedToken),
      }))
      return jsonResponse(401, "Unauthorized")
    }

    const upstream = allowedUpstream(new URL(request.url).searchParams.get("upstream"))
    if (!upstream) return jsonResponse(400, "Unsupported MLB API path")

    try {
      const response = await fetchImpl(upstream, {
        method: "GET",
        headers: {
          accept: "application/json, text/plain, */*",
          "accept-language": "en-US,en;q=0.9",
          "cache-control": "no-cache",
          referer: "https://www.mlb.com/",
          "user-agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36",
        },
        signal: AbortSignal.timeout(30_000),
      })

      console.log(JSON.stringify({
        requestId: context?.requestId,
        path: upstream.pathname,
        status: response.status,
      }))

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: {
          "cache-control": "private, no-store",
          "content-type": response.headers.get("content-type") || "application/json",
          "x-content-type-options": "nosniff",
          "x-ninelens-relay": "1",
        },
      })
    } catch (error) {
      console.error(JSON.stringify({
        requestId: context?.requestId,
        path: upstream.pathname,
        error: error instanceof Error ? error.message : "Unknown upstream error",
      }))
      return jsonResponse(502, "MLB upstream request failed")
    }
  }
}

export default createMlbRelayHandler({
  getSecret: () => process.env.MLB_RELAY_TOKEN,
})
