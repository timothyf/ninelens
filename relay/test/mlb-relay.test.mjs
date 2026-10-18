import assert from "node:assert/strict"
import test from "node:test"

import { createMlbRelayHandler } from "../netlify/functions/mlb-relay.mts"

const relayUrl = "https://relay.example/.netlify/functions/mlb-relay"
const secret = "test-relay-secret"

function request(upstream, token = secret) {
  return new Request(`${relayUrl}?upstream=${encodeURIComponent(upstream)}`, {
    headers: token ? { "x-ninelens-relay-token": token } : {},
  })
}

test("rejects requests without the shared secret", async () => {
  let fetched = false
  const handler = createMlbRelayHandler({
    getSecret: () => secret,
    fetchImpl: async () => {
      fetched = true
      return Response.json({})
    },
  })

  const response = await handler(request("/api/v1/schedule?sportId=1", ""))

  assert.equal(response.status, 401)
  assert.equal(fetched, false)
})

test("reports a missing relay secret as a configuration error", async () => {
  let fetched = false
  const handler = createMlbRelayHandler({
    getSecret: () => undefined,
    fetchImpl: async () => {
      fetched = true
      return Response.json({})
    },
  })

  const originalError = console.error
  console.error = () => {}
  try {
    const response = await handler(request("/api/v1/schedule?sportId=1"))

    assert.equal(response.status, 503)
    assert.deepEqual(await response.json(), { message: "Relay authentication is not configured" })
    assert.equal(fetched, false)
  } finally {
    console.error = originalError
  }
})

test("rejects absolute URLs and non-allowlisted MLB paths", async () => {
  const handler = createMlbRelayHandler({
    getSecret: () => secret,
    fetchImpl: async () => Response.json({}),
  })

  assert.equal((await handler(request("https://example.com/api/v1/schedule"))).status, 400)
  assert.equal((await handler(request("/api/v1/teams"))).status, 400)
})

test("forwards an allowlisted request only to the fixed MLB origin", async () => {
  let fetchedUrl
  let fetchedHeaders
  const handler = createMlbRelayHandler({
    getSecret: () => secret,
    fetchImpl: async (url, options) => {
      fetchedUrl = url
      fetchedHeaders = options.headers
      return Response.json({ dates: [] }, { status: 200 })
    },
  })

  const response = await handler(request("/api/v1/schedule/games/?sportId=1&gameTypes=R%2CW"))

  assert.equal(response.status, 200)
  assert.equal(fetchedUrl.origin, "https://statsapi.mlb.com")
  assert.equal(fetchedUrl.pathname, "/api/v1/schedule/games/")
  assert.equal(fetchedUrl.searchParams.get("gameTypes"), "R,W")
  assert.match(fetchedHeaders["user-agent"], /Mozilla\/5\.0/)
  assert.equal(response.headers.get("x-ninelens-relay"), "1")
  assert.deepEqual(await response.json(), { dates: [] })
})

test("allows league-wide team stats requests", async () => {
  let fetchedUrl
  const handler = createMlbRelayHandler({
    getSecret: () => secret,
    fetchImpl: async (url) => {
      fetchedUrl = url
      return Response.json({ stats: [] }, { status: 200 })
    },
  })

  const response = await handler(request("/api/v1/teams/stats?gameType=R&group=hitting&season=2026&sportIds=1&stats=season"))

  assert.equal(response.status, 200)
  assert.equal(fetchedUrl.pathname, "/api/v1/teams/stats")
  assert.equal(fetchedUrl.searchParams.get("sportIds"), "1")
})

test("passes an MLB upstream failure through to NineLens", async () => {
  const handler = createMlbRelayHandler({
    getSecret: () => secret,
    fetchImpl: async () => Response.json({ message: "Not found" }, { status: 404 }),
  })

  const response = await handler(request("/api/v1/people/1"))

  assert.equal(response.status, 404)
  assert.deepEqual(await response.json(), { message: "Not found" })
})
