#!/usr/bin/env python3
"""
NexWorker RAG - LanceDB based document search
Wissensbasis: /app/storage/wissensbasis/
"""

import os
import sys
import json
import glob
import argparse
from pathlib import Path

import lancedb
import pyarrow as pa
from sentence_transformers import SentenceTransformer
from pypdf import PdfReader

# Config
KB_DIR = "/app/storage/wissensbasis"
DB_PATH = "/app/storage/lancedb"
COLLECTION_NAME = "nexworker_docs"
EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
EMBEDDING_DIM = 384

def extract_text_from_pdf(pdf_path):
    """Extract text from PDF file"""
    try:
        reader = PdfReader(pdf_path)
        text = ""
        for page in reader.pages:
            text += page.extract_text() + "\n"
        return text[:10000]
    except Exception as e:
        print(f"Error reading {pdf_path}: {e}")
        return ""

def get_all_docs():
    """Get all documents from knowledge base"""
    docs = []
    for ext in ["*.pdf", "*.md", "*.txt"]:
        for f in glob.glob(os.path.join(KB_DIR, ext)):
            docs.append(f)
    return docs

def index_documents():
    """Index all documents in knowledge base"""
    print("📚 Lade Embedding-Modell...")
    model = SentenceTransformer(EMBEDDING_MODEL)
    
    print("📂 Scanne Wissensbasis...")
    docs = get_all_docs()
    print(f"   Gefunden: {len(docs)} Dateien")
    
    if not docs:
        print("❌ Keine Dokumente gefunden!")
        return
    
    # Prepare data
    records = []
    for doc_path in docs:
        filename = os.path.basename(doc_path)
        print(f"   📄 Verarbeite: {filename}")
        
        if doc_path.endswith(".pdf"):
            content = extract_text_from_pdf(doc_path)
        else:
            with open(doc_path, 'r', encoding='utf-8') as f:
                content = f.read()
        
        if content.strip():
            records.append({
                "filename": filename,
                "content": content,
                "path": doc_path
            })
    
    if not records:
        print("❌ Kein verarbeitbarer Inhalt gefunden!")
        return
    
    print("🔢 Generiere Embeddings...")
    contents = [r["content"] for r in records]
    embeddings = model.encode(contents, show_progress_bar=True)
    
    # Add to LanceDB
    db = lancedb.connect(DB_PATH)
    
    # Drop existing table
    try:
        db.drop_table(COLLECTION_NAME)
    except:
        pass
    
    # Create schema
    schema = pa.schema([
        ("filename", pa.string()),
        ("content", pa.string()),
        ("path", pa.string()),
        ("vector", pa.list_(pa.float32(), EMBEDDING_DIM))
    ])
    
    # Create table with data
    data = [
        {
            "filename": r["filename"],
            "content": r["content"],
            "path": r["path"],
            "vector": v.tolist()
        }
        for r, v in zip(records, embeddings)
    ]
    
    tbl = db.create_table(COLLECTION_NAME, data=data)
    
    print(f"✅ Indexiert: {len(records)} Dokumente")
    return len(records)

def search(query, top_k=3):
    """Search documents"""
    if not os.path.exists(DB_PATH):
        print("❌ Keine Datenbank gefunden! Zuerst indexieren.")
        return []
    
    print(f"🔍 Suche: '{query}'")
    model = SentenceTransformer(EMBEDDING_MODEL)
    query_embedding = model.encode([query])[0].tolist()
    
    db = lancedb.connect(DB_PATH)
    tbl = db.open_table(COLLECTION_NAME)
    
    results = tbl.search(query_embedding).limit(top_k).to_list()
    
    print(f"   Gefunden: {len(results)} Treffer")
    return [
        {
            "filename": r["filename"],
            "content": r["content"][:500] + "..." if len(r["content"]) > 500 else r["content"],
            "path": r["path"]
        }
        for r in results
    ]

def main():
    parser = argparse.ArgumentParser(description="NexWorker RAG")
    parser.add_argument("command", choices=["index", "search"], help="Command to run")
    parser.add_argument("--query", "-q", help="Search query")
    parser.add_argument("--top-k", "-k", type=int, default=3, help="Number of results")
    
    args = parser.parse_args()
    
    if args.command == "index":
        index_documents()
    elif args.command == "search":
        if not args.query:
            print("❌ Bitte Query angeben mit --query")
            sys.exit(1)
        results = search(args.query, args.top_k)
        print("\n📋 Ergebnisse:")
        for i, r in enumerate(results, 1):
            print(f"\n{i}. {r['filename']}")
            print(f"   {r['content'][:200]}...")

if __name__ == "__main__":
    main()
