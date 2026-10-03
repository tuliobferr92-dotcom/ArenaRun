# REINOS — Diretrizes de Conteúdo Bíblico

## Princípio fundamental
Nenhuma IA gera, sozinha, conteúdo bíblico publicado diretamente para jogadores.
Toda referência, pergunta, descrição histórica ou dado de personagem passa por um pipeline com três estados:

```
GENERATED_CONTENT -> REVIEWED_CONTENT -> PUBLISHED_CONTENT
```

- **GENERATED_CONTENT**: rascunho (de IA ou de um redator), nunca visível no app.
- **REVIEWED_CONTENT**: revisado por um humano responsável por conteúdo bíblico/histórico; ainda não publicado.
- **PUBLISHED_CONTENT**: aprovado, versionado, é o único estado que o `ContentRepository` entrega ao cliente.

Cada item de conteúdo (pergunta, verbete do Codex, carta territorial, evento) tem um `reviewStatus` e
`sourceMetadata` (quem escreveu, quem revisou, data, referências usadas).

## Regras editoriais
1. **Verificabilidade primeiro.** Priorizar fatos diretamente verificáveis no texto bíblico e em
   contexto histórico/geográfico amplamente estabelecido (consenso acadêmico majoritário).
2. **Neutralidade em divergências interpretativas.** Quando houver diferenças relevantes entre tradições
   teológicas (datas, identificações geográficas incertas, interpretações de eventos), o conteúdo deve
   indicar a incerteza ("segundo uma tradição...", "a localização exata é debatida") em vez de apresentar
   uma posição como fato universal.
3. **Separação jogo ↔ história.** Mecânicas de jogo (cartas de evento, bônus, objetivos) são inspiradas em
   temas bíblicos, mas o texto da UI nunca afirma que o efeito de jogo representa literalmente o
   significado teológico do texto. Ex.: a carta "Sabedoria" (tema Salomão) concede uma vantagem
   estratégica no jogo; a UI não deve dizer que isso "é" a sabedoria de Salomão.
4. **Objetivos nunca deturpam a Bíblia.** Um objetivo secreto de conquista territorial não deve ser
   apresentado como equivalente ao acontecimento histórico/bíblico real.
5. **Sem clichês religiosos genéricos.** Evitar iconografia piedosa estereotipada; a direção de arte é
   "mundo antigo + jogo de estratégia moderno", não "material de escola bíblica".
6. **Datas incertas.** O modelo de dados de `HistoricalPeriod`/`BiblicalEvent` usa **intervalos** e um
   campo de **nível de certeza** (`certain`, `approximate`, `debated`) em vez de datas absolutas únicas
   quando a cronologia é incerta.
7. **Coexistência política.** Territórios de períodos diferentes (ex.: Roma e o Reino Unido de Israel) não
   são apresentados como coexistindo politicamente no mesmo mapa/período; cada `GameMap` é associado a um
   `HistoricalPeriod` coerente.

## Pipeline operacional (fases futuras)
1. Redator/pesquisador (humano ou IA) cria item em `GENERATED_CONTENT` com `sourceMetadata` completo.
2. Revisor humano aprova, edita ou rejeita → `REVIEWED_CONTENT`.
3. Processo de release move para `PUBLISHED_CONTENT`, versionado (nunca editado in-place; nova versão).
4. `ContentRepository` do app só lê `PUBLISHED_CONTENT`.

## Nesta fundação (Fase 1)
O conteúdo bíblico incluído na Fase 1 é mínimo (poucos territórios com 1 referência curta cada,
ex.: "Jericó — Josué 6") e é tratado, desde já, como `PUBLISHED_CONTENT` de exemplo — escrito de forma
conservadora e verificável — exatamente para validar o pipeline de dados, não para ser conteúdo final.
Qualquer expansão de conteúdo bíblico deve seguir o processo de revisão acima antes de ir para produção.
