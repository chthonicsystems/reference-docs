---
library: ai
version: 0.1.0
related-rfcs: [0013]
last-verified: 2026-05-22
tags: [ai, consumption]
summary: Code-level integration walkthrough.
---

# Consuming `@chthonic/ai`

## 1. Add packages

```xml
<PackageReference Include="Chthonic.AI" Version="0.1.0" />
```

```json
"@chthonicsystems/ai": "0.1.0"
```

## 2. Configure secrets

```bash
AWS_REGION=us-east-1
AWS__Bedrock__AccessKeyId=AKIA...
AWS__Bedrock__SecretAccessKey=...
AWS__Bedrock__ModelId=anthropic.claude-sonnet-4-5-20250929-v1:0

AI__KeypairSecretName=torque-tech-ai-keypair-prod
AI__LogGroupName=/torquetech/ai-generations-prod
AI__ApiBaseUrl=https://torquetech.chthonicsystems.com
```

## 3. Provision keypair

```bash
aws secretsmanager create-secret --name torque-tech-ai-keypair-prod \
  --secret-string '{"privateKey":"-----BEGIN EC PRIVATE KEY-----\n...","publicKey":"-----BEGIN PUBLIC KEY-----\n..."}'
```

## 4. Create CloudWatch log group

```bash
aws logs create-log-group --log-group-name /torquetech/ai-generations-prod
aws logs put-retention-policy --log-group-name /torquetech/ai-generations-prod --retention-in-days 30
```

## 5. Register DI

```csharp
using Chthonic.AI;
builder.Services.AddChthonicAi(builder.Configuration);

// Per AI feature, register an IToolExecutor:
builder.Services.AddScoped<IToolExecutor, ConfigImportToolExecutor>();
builder.Services.AddScoped<IToolExecutor, ListingTemplateToolExecutor>();
builder.Services.AddScoped<IToolExecutor, AiJobCardTemplateToolExecutor>();
// ... etc

app.MapAiGenerationsEndpoints();
```

## 6. Frontend

```tsx
import { setAiHttp, AiPill } from '@chthonicsystems/ai';
setAiHttp(httpService);

<AiPill type="info" /> {/* "✨ AI" badge */}
```

## Related

- [`tool-executor-pattern.md`](tool-executor-pattern.md), [`ecdsa-keypair-auth.md`](ecdsa-keypair-auth.md), [`ui-shells.md`](ui-shells.md).
