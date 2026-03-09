# Nex-Assistent Tech-Stack

## Architektur-Übersicht

```
┌─────────────────────────────────────────────────┐
│                   Frontend                       │
│  ┌─────────────┐  ┌─────────────┐               │
│  │  Web App    │  │  Mobile App │               │
│  │  (React)    │  │  (React     │               │
│  │             │  │   Native)   │               │
│  └─────────────┘  └─────────────┘               │
└──────────────────────┬──────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│                   Backend                        │
│  ┌─────────────┐  ┌─────────────┐               │
│  │  REST API   │  │  WebSocket  │               │
│  │  (Node.js)  │  │  (Chat)     │               │
│  └─────────────┘  └─────────────┘               │
└──────────────────────┬──────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
┌──────────────┐ ┌──────────┐ ┌──────────────┐
│   Services   │ │   AI     │ │   Storage    │
├──────────────┤ ├──────────┤ ├──────────────┤
│ OCR Service  │ │ GPT-4o   │ │ Vector DB    │
│ (Google      │ │ Gemini   │ │ (Pinecone)   │
│  Vision)     │ │ Flash    │ │              │
│              │ │          │ │ Postgres     │
│              │ │          │ │ (Supabase)   │
└──────────────┘ └──────────┘ └──────────────┘
```

---

## Frontend

### Web App
- **Framework:** React 18 / Next.js 14
- **Styling:** Tailwind CSS
- **State:** Zustand oder React Query
- **Chat:** Vercel AI SDK

### Mobile App (Phase 2)
- **Framework:** React Native / Expo
- **Kamera:** expo-camera
- **Offline:** AsyncStorage

---

## Backend

### API Server
- **Runtime:** Node.js 20 LTS
- **Framework:** Fastify oder Express
- **Language:** TypeScript
- **Validation:** Zod

### Real-Time Chat
- **WebSocket:** Socket.io oder Pusher
- **AI-Streaming:** Vercel AI SDK

---

## AI Services

### OCR (Optical Character Recognition)

**Option A: Google Cloud Vision API**
- ✅ Sehr hohe Accuracy
- ✅ Deutsche Sprache gut unterstützt
- ❌ Kosten: ~1.50€ pro 1000 Seiten

**Option B: AWS Textract**
- ✅ Günstiger
- ✅ Forms-Extraction
- ❌ Weniger gut für Deutsch

**Empfehlung:** Google Cloud Vision (MVP)

---

### Kategorisierung & Extraction

**Option A: GPT-4o-mini**
- ✅ Schnell & günstig
- ✅ Gute deutsche Sprache
- ✅ Structured Output
- Kosten: ~0.15€ pro 1M Input Tokens

**Option B: Gemini 2.0 Flash**
- ✅ Noch günstiger
- ✅ Multimodal (kann direkt Bilder)
- Kosten: Kostenlos bis Threshold

**Empfehlung:** GPT-4o-mini für Text, Gemini Flash für Bild-Analyse

---

### Embeddings & Search

**Option A: OpenAI text-embedding-3-small**
- ✅ Günstig
- ✅ Gute Performance
- Kosten: ~0.02€ pro 1M Tokens

**Option B: Google Gemini Embedding**
- ✅ Kostenlos bis Threshold
- ✅ Gute deutsche Sprache

**Empfehlung:** OpenAI Embeddings (stabil, gut dokumentiert)

---

## Database

### Vector Database

**Option A: Pinecone**
- ✅ Managed Service
- ✅ Schnell
- ❌ Kosten ab $70/Monat

**Option B: Supabase pgvector**
- ✅ Kostenlos bis 500MB
- ✅ PostgreSQL (bekannt)
- ✅ Built-in Auth

**Option C: Weaviate (Self-hosted)**
- ✅ Kostenlos
- ✅ Open Source
- ❌ Wartung nötig

**Empfehlung:** Supabase (MVP) → Pinecone (Scale)

---

### Relational Database

**Option A: Supabase (PostgreSQL)**
- ✅ Managed
- ✅ Built-in Auth
- ✅ Real-time
- ✅ Kostenlos bis 500MB

**Option B: PlanetScale (MySQL)**
- ✅ Serverless
- ✅ Branching
- ❌ Keine Vectors

**Empfehlung:** Supabase (ein Service für alles)

---

## Storage

### File Storage

**Option A: Supabase Storage**
- ✅ Integriert mit DB
- ✅ Kostenlos bis 1GB

**Option B: AWS S3**
- ✅ Unbegrenzt skalierbar
- ✅ Günstig
- ❌ Extra Setup

**Empfehlung:** Supabase Storage (MVP)

---

## Infrastructure

### Hosting

**Frontend:** Vercel
- ✅ Kostenlos für Hobby
- ✅ Auto-Deploy
- ✅ Edge Functions

**Backend:** Railway oder Render
- ✅ Einfaches Deployment
- ✅ Auto-Scaling
- ✅ Kostenlos für MVP

**Database:** Supabase Cloud
- ✅ Kostenlos bis 500MB
- ✅ Auto-Backup

---

## External Services

### E-Mail
- **Transactional:** Resend oder Postmark
- **Inbound:** Parse emails with Supabase Edge Functions

### Push Notifications
- **Web:** VAPID (selbst gehostet)
- **Mobile:** Expo Push Notifications

### Payments
- **Stripe:** Alle Zahlungsarten
- **Deutschland:** SEPA Direct Debit

---

## Security

### Authentication
- **Supabase Auth** (JWT-based)
- Magic Link oder E-Mail/Password
- OAuth (Google, Microsoft) optional

### Data Protection
- **Encryption at Rest:** Supabase Default
- **Encryption in Transit:** TLS 1.3
- **GDPR:** EU-Server (Frankfurt)

### API Security
- Rate Limiting (Redis)
- Input Validation (Zod)
- CORS konfiguriert

---

## Tech Stack Summary (MVP)

| Komponente | Technologie |
|------------|-------------|
| Frontend | React + Next.js + Tailwind |
| Backend | Node.js + Fastify + TypeScript |
| Database | Supabase (PostgreSQL + Storage) |
| Vector DB | Supabase pgvector |
| OCR | Google Cloud Vision |
| AI | GPT-4o-mini + Gemini Flash |
| Embeddings | OpenAI text-embedding-3-small |
| Hosting | Vercel (Frontend) + Railway (Backend) |
| Auth | Supabase Auth |
| Payments | Stripe |

---

## Estimated Costs (MVP)

### Monatlich (bei 1000 Dokumenten)

| Service | Kosten |
|---------|--------|
| Supabase Pro | $25 |
| Google Vision | ~$2 |
| OpenAI API | ~$5 |
| Gemini API | $0 (free tier) |
| Railway | $5 |
| Vercel | $0 (free tier) |
| **Gesamt** | **~$37/Monat** |

### Bei 10.000 Dokumenten/Monat

| Service | Kosten |
|---------|--------|
| Supabase Pro | $25 |
| Google Vision | ~$15 |
| OpenAI API | ~$20 |
| Gemini API | ~$5 |
| Railway | $10 |
| **Gesamt** | **~$75/Monat** |

---

## Scaling Path

### Phase 1 (MVP)
- Supabase Free Tier
- Railway Free Tier
- OpenAI API

### Phase 2 (100+ Nutzer)
- Pinecone für Vectors
- Redis für Caching
- Queue System (Bull/BullMQ)

### Phase 3 (1000+ Nutzer)
- Kubernetes Cluster
- Multi-Region
- Dedicated OCR Workers
