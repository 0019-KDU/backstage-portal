# Bindings: resources this service uses

One JSON file per resource and environment, usually added by a Backstage request
("S3 bucket" / "PostgreSQL database" with *Connect to service* ticked):

```
bindings/dev/s3-shop-images.json
{"type": "s3", "name": "shop-images", "access": "read-write", "env_prefix": "SHOP_IMAGES"}
```

On the next deployment of that environment the service gets:

| type | environment variables | permissions |
|---|---|---|
| `s3` | `<PREFIX>_BUCKET` | list + read (+ write/delete for `read-write`) on that bucket only |
| `rds-postgres` | `<PREFIX>_HOST`, `_PORT`, `_NAME`, `_USER`, `_PASSWORD` (secret) | network access is already allowed inside the environment |

The resource must exist before the binding is deployed (merge the resource request first).
Remove the file to revoke access.
