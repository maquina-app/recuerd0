// Derived from Writebook by 37signals — MIT licensed. See NOTICE.md.
// https://github.com/basecamp/writebook
import { FetchRequest } from "@rails/request.js"

export async function submitForm(form) {
  const request = new FetchRequest(form.method, form.action, {
    body: new FormData(form)
  })

  return await request.perform()
}
