# Replace base_url with your project's own development/test API.
GET {{base_url}}/health
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
