export async function generateLocalEmbedding(content: string) {
  // Windows コンテナでは使わない（ACRビルド含む）
  if (process.platform === "win32") {
    throw new Error("Local embedding is not supported on Windows container")
  }

  // ここで初めて読み込む（ビルド時の評価で落ちにくくする）
  const { pipeline } = await import("@xenova/transformers")

  const generateEmbedding = await pipeline(
    "feature-extraction",
    "Xenova/all-MiniLM-L6-v2"
  )

  const output = await generateEmbedding(content, {
    pooling: "mean",
    normalize: true
  })

  return Array.from(output.data)
}

