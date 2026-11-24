// Sets the CORS rule Formbricks needs on its S3 bucket (browser uploads use presigned POST URLs).
// Dependency-free AWS Signature V4 request: PUT /?cors on the virtual-hosted bucket URL.
// Exits 0 on success, 1 on failure (the caller only logs; uploads are the only thing affected).
import { createHash, createHmac } from "node:crypto";

const { S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET_NAME, S3_ENDPOINT_URL } = process.env;
const region = process.env.S3_REGION || "us-east-1";

if (!S3_ACCESS_KEY || !S3_SECRET_KEY || !S3_BUCKET_NAME || !S3_ENDPOINT_URL) {
  console.log("[bucket-cors] S3 is not configured; skipping");
  process.exit(0);
}

// Upstream's documented rule allows any origin: surveys embedded on other sites upload from those origins.
const origins = ["*"];

const body = `<?xml version="1.0" encoding="UTF-8"?>
<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <CORSRule>
${origins.map((o) => `    <AllowedOrigin>${o}</AllowedOrigin>`).join("\n")}
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>HEAD</AllowedMethod>
    <AllowedMethod>POST</AllowedMethod>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>DELETE</AllowedMethod>
    <AllowedHeader>*</AllowedHeader>
    <ExposeHeader>ETag</ExposeHeader>
    <MaxAgeSeconds>3000</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>`;

const endpoint = new URL(S3_ENDPOINT_URL);
const forcePathStyle = process.env.S3_FORCE_PATH_STYLE === "1";
const host = forcePathStyle ? endpoint.host : `${S3_BUCKET_NAME}.${endpoint.host}`;
const path = forcePathStyle ? `/${S3_BUCKET_NAME}/` : "/";

const sha256 = (data) => createHash("sha256").update(data).digest("hex");
const hmac = (key, data) => createHmac("sha256", key).update(data).digest();

const now = new Date();
const amzDate = now.toISOString().replace(/[:-]|\.\d{3}/g, "");
const dateStamp = amzDate.slice(0, 8);
const payloadHash = sha256(body);
const contentMd5 = createHash("md5").update(body).digest("base64");

const headers = {
  "content-md5": contentMd5,
  "content-type": "application/xml",
  host,
  "x-amz-content-sha256": payloadHash,
  "x-amz-date": amzDate,
};
const signedHeaders = Object.keys(headers).sort().join(";");
const canonicalHeaders = Object.keys(headers)
  .sort()
  .map((k) => `${k}:${headers[k]}\n`)
  .join("");
const canonicalRequest = ["PUT", path, "cors=", canonicalHeaders, signedHeaders, payloadHash].join("\n");
const scope = `${dateStamp}/${region}/s3/aws4_request`;
const stringToSign = ["AWS4-HMAC-SHA256", amzDate, scope, sha256(canonicalRequest)].join("\n");
const signingKey = hmac(hmac(hmac(hmac(`AWS4${S3_SECRET_KEY}`, dateStamp), region), "s3"), "aws4_request");
const signature = createHmac("sha256", signingKey).update(stringToSign).digest("hex");

try {
  const res = await fetch(`${endpoint.protocol}//${host}${path}?cors=`, {
    method: "PUT",
    headers: {
      ...headers,
      authorization: `AWS4-HMAC-SHA256 Credential=${S3_ACCESS_KEY}/${scope}, SignedHeaders=${signedHeaders}, Signature=${signature}`,
    },
    body,
    signal: AbortSignal.timeout(20_000),
  });
  if (!res.ok) {
    console.log(`[bucket-cors] PutBucketCors answered ${res.status}: ${(await res.text()).slice(0, 300)}`);
    process.exit(1);
  }
  console.log(`[bucket-cors] CORS rule set on bucket ${S3_BUCKET_NAME}`);
} catch (err) {
  console.log(`[bucket-cors] could not reach the bucket: ${err.message}`);
  process.exit(1);
}
