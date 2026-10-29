import assert from "node:assert/strict"
import test from "node:test"
import { createFangraphsRelayHandler } from "../netlify/functions/fangraphs-relay.mts"

const relayUrl = "https://relay.example/.netlify/functions/fangraphs-relay"
const secret = "test-relay-secret"

function request(upstream, token = secret, method = "GET") {
  return new Request(`${relayUrl}?upstream=${encodeURIComponent(upstream)}`, {
    method,
    headers: token ? { "x-ninelens-relay-token": token } : {},
  })
}

test("forwards the FanGraphs leaderboard path and query", async () => {
  let receivedUrl
  const handler = createFangraphsRelayHandler({
    getSecret: () => secret,
    fetchImpl: async (url) => {
      receivedUrl = url
      return Response.json({ data: [{ WAR: 2.5 }] })
    },
  })
  const response = await handler(request("/api/leaders/major-league/data?stats=bat&season=2026"))

  assert.equal(response.status, 200)
  assert.equal(response.headers.get("x-ninelens-relay"), "1")
  assert.equal(receivedUrl.toString(), "https://www.fangraphs.com/api/leaders/major-league/data?stats=bat&season=2026")
  assert.deepEqual(await response.json(), { data: [{ WAR: 2.5 }] })
})

test("requires the shared token and rejects unsupported methods and paths", async () => {
  let calls = 0
  const handler = createFangraphsRelayHandler({ getSecret: () => secret, fetchImpl: async () => { calls += 1; return Response.json({}) } })
  assert.equal((await handler(request("/api/leaders/major-league/data", null))).status, 401)
  assert.equal((await handler(request("/api/leaders/major-league/data", "wrong"))).status, 401)
  assert.equal((await handler(request("/api/leaders/major-league/data", secret, "POST"))).status, 405)
  assert.equal((await handler(request("/roster-resource/payroll/tigers"))).status, 400)
  assert.equal((await handler(request("//evil.example/api/leaders/major-league/data"))).status, 400)
  assert.equal(calls, 0)
})

test("reports missing authentication config and upstream failures", async () => {
  const unconfigured = createFangraphsRelayHandler({ getSecret: () => undefined })
  assert.equal((await unconfigured(request("/api/leaders/major-league/data"))).status, 503)

  const failing = createFangraphsRelayHandler({ getSecret: () => secret, fetchImpl: async () => { throw new Error("connection failed") } })
  assert.equal((await failing(request("/api/leaders/major-league/data"))).status, 502)
})
