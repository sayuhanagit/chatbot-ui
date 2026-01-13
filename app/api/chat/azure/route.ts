import { checkApiKey, getServerProfile } from "@/lib/server/server-chat-helpers"
import { ChatAPIPayload } from "@/types"
import { OpenAIStream, StreamingTextResponse } from "ai"
import OpenAI from "openai"
import type { ChatCompletionMessageParam } from "openai/resources/chat/completions"

export const runtime = "edge"

// ===== Azure AI Search =====
// ★ ! を外して「未設定の可能性がある」前提で受ける
const SEARCH_ENDPOINT = process.env.AZURE_AI_SEARCH_ENDPOINT
const SEARCH_KEY = process.env.AZURE_AI_SEARCH_API_KEY
const SEARCH_INDEX = process.env.AZURE_AI_SEARCH_INDEX_NAME
const SEARCH_TOP_K = Number(process.env.AZURE_AI_SEARCH_TOP_K ?? "5")

// ★ Search が有効かどうか（3つ揃った時だけ true）
const searchEnabled = !!(SEARCH_ENDPOINT && SEARCH_KEY && SEARCH_INDEX)

async function searchDocuments(query: string) {
  // ★ 未設定なら検索しない（落とさない）
  if (!searchEnabled) {
    return { value: [] as any[] }
  }

  const res = await fetch(
    `${SEARCH_ENDPOINT!}/indexes/${encodeURIComponent(
      SEARCH_INDEX!
    )}/docs/search?api-version=2023-11-01`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "api-key": SEARCH_KEY!
      },
      body: JSON.stringify({
        search: query,
        top: SEARCH_TOP_K
      })
    }
  )

  if (!res.ok) {
    const t = await res.text().catch(() => "")
    throw new Error(`Azure AI Search failed: ${res.status} ${t}`)
  }

  return res.json() as Promise<{ value: any[] }>
}

function buildRagContext(docs: any[]) {
  return (docs ?? [])
    .map((d, i) => {
      const body = d.content ?? d.text ?? d.chunk ?? d.body ?? ""
      const title = d.title ?? d.filename ?? `doc_${i + 1}`
      return `【${i + 1}】${title}\n${body}`
    })
    .filter(Boolean)
    .join("\n\n")
    .slice(0, 12000)
}

function toOpenAiRole(role: string): "system" | "user" | "assistant" {
  if (role === "system" || role === "assistant" || role === "user") return role
  // ★ 不明な role は system に寄せる（安全）
  return "system"
}

export async function POST(request: Request) {
  const json = await request.json()
  const { chatSettings, messages } = json as ChatAPIPayload

  try {
    const profile = await getServerProfile()
    checkApiKey(profile.azure_openai_api_key, "Azure OpenAI")

    const ENDPOINT = profile.azure_openai_endpoint
    const KEY = profile.azure_openai_api_key

    let DEPLOYMENT_ID = ""
    switch (chatSettings.model) {
  　　case "gpt-4o":
    　　DEPLOYMENT_ID = profile.azure_openai_45_turbo_id || ""
    　　break
  　　default:
   　　 return new Response(JSON.stringify({ message: "サポート外のモデルです。" }), {
      　　status: 400
    })
}

    }

    if (!ENDPOINT || !KEY || !DEPLOYMENT_ID) {
      return new Response(JSON.stringify({ message: "Azure resources not found" }), {
        status: 400
      })
    }

    // ===== RAG: Azure AI Search =====
    const userMessage = messages?.[messages.length - 1]?.content ?? ""
    const openAiMessages: ChatCompletionMessageParam[] = []

    // ★ Search が設定されている場合だけ実行
    if (searchEnabled && userMessage) {
      const searchResult = await searchDocuments(userMessage)
      const context = buildRagContext(searchResult.value ?? [])
      if (context) {
        openAiMessages.push({
          role: "system",
          content:
            "以下の検索結果を根拠に、日本語で正確に回答してください。\n\n" +
            context
        })
      }
    }

    // Chatbot UI 独自 message → OpenAI message に変換
    for (const m of messages ?? []) {
      openAiMessages.push({
        role: toOpenAiRole(m.role),
        content: m.content ?? ""
      })
    }

    const azureOpenai = new OpenAI({
      apiKey: KEY,
      baseURL: `${ENDPOINT}/openai/deployments/${DEPLOYMENT_ID}`,
      defaultQuery: { "api-version": "2024-06-01" },
      defaultHeaders: { "api-key": KEY }
    })

    const response = await azureOpenai.chat.completions.create({
      model: DEPLOYMENT_ID,
      messages: openAiMessages,
      temperature: chatSettings.temperature,
      stream: true
    })

    const stream = OpenAIStream(response)
    return new StreamingTextResponse(stream)
  } catch (error: any) {
    const errorMessage = error.error?.message || "An unexpected error occurred"
    const errorCode = error.status || 500
    return new Response(JSON.stringify({ message: errorMessage }), {
      status: errorCode
    })
  }
}
