import os
import sys
import time
import base64
from litellm import completion

import tiktoken

enc = tiktoken.get_encoding("cl100k_base")

# Asegúrate de tener tu API key configurada:
#   export GEMINI_API_KEY="tu-api-key"
# o descomenta la siguiente línea:
os.environ["GEMINI_API_KEY"] = "[ENCRYPTION_KEY]"

# Uso: python test_gemini_flash.py [ruta_imagen]
image_path = (
    sys.argv[1]
    if len(sys.argv) > 1
    else "/Users/esteban/Documents/Naowee_Jorge/Agents/Ideas/scripts/p30_i4.png"
)


def chunk_text(text: str, max_tokens: int = 80) -> list[str]:
    """
    Divide un texto en chunks que no superen max_tokens tokens (tiktoken cl100k_base).
    La división respeta los límites de palabras.
    """
    text = text.strip()
    words = text.split()
    chunks = []
    current_words = []

    for word in words:
        current_words.append(word)
        token_count = len(enc.encode(" ".join(current_words)))

        if token_count > max_tokens:
            current_words.pop()
            chunks.append(" ".join(current_words))
            current_words = [word]

    if current_words:
        chunks.append(" ".join(current_words))

    return chunks


source_name = "Manual de usuario – Comité Olímpico Colombiano"

text_before_image = """
Para vincular a un personal de apoyo, debe acceder a la pestaña "Estudiantes" al estudiante correspondiente y hacer clic en el ícono de los tres puntos ubicado en la columna "Acciones" Una vez desplegado el menú, seleccione la opción "Agregar personal de apoyo" para iniciar el proceso de vinculación.
"""

text_after_image = """
Tenga en cuenta que el personal de apoyo debe tener asignado el mismo deporte que el estudiante. Una vez identificado el personal adecuado, selecciónelo en la lista disponible y haga clic en el botón "Agregar personal de apoyo seleccionado" para completar el proceso de vinculación.
"""

text_before_imagen_clean = chunk_text(text_before_image, max_tokens=80)
text_after_imagen_clean = chunk_text(text_after_image, max_tokens=80)

PROMPT = f"""
Eres un sistema de indexación semántica. Tu tarea es generar una descripción 
funcional de una imagen de interfaz de usuario para ser usada en un sistema RAG.

Redacta un único párrafo denso en información que explique:
- Qué módulo o sección del sistema representa
- Qué acción principal permite ejecutar el usuario
- Qué tipo de datos o entidades gestiona
- Los campos, botones o etiquetas clave visibles (nómbralos textualmente)

Restricciones:
- Sin listas, enumeraciones ni viñetas en la respuesta
- Sin descripciones de colores, íconos decorativos ni layout visual
- Sin inferencias: solo lo que sea claramente visible en la interfaz
- Entre 60 y 90 palabras

Contexto de recuperación:
- Documento fuente: {source_name}
- Texto anterior a la imagen: {text_before_imagen_clean}
- Texto posterior a la imagen: {text_after_imagen_clean}
"""

if image_path:
    with open(image_path, "rb") as f:
        image_data = base64.b64encode(f.read()).decode("utf-8")

    # Detectar tipo MIME según extensión
    ext = os.path.splitext(image_path)[1].lower()
    mime_map = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".gif": "image/gif",
        ".webp": "image/webp",
    }
    mime_type = mime_map.get(ext, "image/jpeg")

    content = [
        {"type": "text", "text": PROMPT},
        {
            "type": "image_url",
            "image_url": {"url": f"data:{mime_type};base64,{image_data}"},
        },
    ]
    print(f"Enviando imagen '{image_path}' a Gemini para descripción...")
else:
    content = "Explica en 3 oraciones qué es la inteligencia artificial."
    print("Enviando solicitud de texto a Gemini...")

t0 = time.time()

response = completion(
    model="gemini/gemma-3-27b-it",
    messages=[{"role": "user", "content": content}],
    temperature=0.7,
    max_tokens=150,
)

elapsed = time.time() - t0

print(f"\nRespuesta:\n{response.choices[0].message.content}")
print(f"\nTiempo: {elapsed:.2f}s")
print(f"Tokens input: {response.usage.prompt_tokens}")
print(f"Tokens output: {response.usage.completion_tokens}")
print(f"Tokens total: {response.usage.total_tokens}")
