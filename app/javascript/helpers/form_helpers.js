// Derived from Writebook by 37signals — MIT licensed. See NOTICE.md.
// https://github.com/basecamp/writebook
import { FetchRequest } from "@rails/request.js"

// `extra` adds fields the markup does not carry — used to mark a submission as
// an autosave so the server can answer 204 instead of redirecting.
export async function submitForm(form, extra = {}) {
  const body = new FormData(form)
  for (const [key, value] of Object.entries(extra)) body.set(key, value)

  const request = new FetchRequest(form.method, form.action, { body })

  return await request.perform()
}
