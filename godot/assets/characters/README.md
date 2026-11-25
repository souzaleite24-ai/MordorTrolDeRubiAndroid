# Personagens 3D — pipeline de produção

Esta pasta recebe os modelos finais de personagens de **Mordor 3D — Crônicas de Mordor**.
Os personagens procedurais atuais continuam como fallback até que cada modelo seja
importado e validado no Android. Não substituir o fallback por um arquivo ausente ou
por um modelo cuja licença não permita redistribuição no jogo.

## Formato e nomes

Preferir **glTF 2.0 binário (.glb)** exportado pelo Blender. O importador do Godot 4.3
preserva malhas, materiais PBR, esqueletos e animações nesse formato.

Nomes reservados para integração:

| Arquivo | Personagem |
|---|---|
| `senhor_sombrio.glb` | Jogador |
| `brutamontes.glb` | Aliado — Brutamontes |
| `assassino.glb` | Aliado — Assassino |
| `piromante.glb` | Aliado — Piromante |
| `xama.glb` | Aliado — Xamã |
| `guardiao_corrompido.glb` | Inimigo comum |
| `nekravor.glb` | Chefe |
| `oraculo_das_cinzas.glb` | NPC |

## Requisitos de entrega

- Malha retopologizada para jogo; escultura high-poly deve ser usada como origem para
  bake, não como malha final renderizada em massa.
- UVs sem sobreposição indesejada e texturas PBR (Base Color, Normal e ORM quando usadas).
- Esqueleto humanoide consistente, pose de repouso documentada e pesos de skinning limpos.
- Animações nomeadas e incluídas no GLB: `idle`, `walk`, `run`, `attack`, `hit`,
  `death`; personagens especiais podem ter clipes adicionais.
- Escala em metros, eixo vertical Y, origem no chão entre os pés e frente do personagem
  orientada para -Z.
- Materiais e texturas compactos. Começar com texturas 1K; subir para 2K apenas quando
  a leitura visual justificar o custo.
- Preparar LODs ou validar a geração automática de LOD do Godot, especialmente para
  inimigos em grupo. Conferir visualmente malhas esqueléticas após a dizimação.

## Orçamento técnico inicial (metas, não limites rígidos)

- Personagens de horda: alvo de 10–25 mil triângulos no LOD próximo.
- Jogador, NPC e chefe: alvo de 20–40 mil triângulos no LOD próximo.
- Pelo menos dois níveis de detalhe para personagens vistos a distância.
- Evitar materiais transparentes e luzes individuais em excesso na horda.

As metas devem ser medidas no dispositivo Android de referência; qualidade visual e
taxa de quadros têm prioridade sobre atingir um número arbitrário de polígonos.

## Licença e proveniência obrigatórias

Antes de adicionar qualquer modelo, registrar aqui: autor, URL de origem, licença exata,
data de obtenção, comprovante/arquivo de licença e modificações realizadas. “Grátis para
baixar” não significa automaticamente livre para uso comercial ou redistribuição.
Não adicionar assets pagos sem autorização explícita de compra.

## Estado

Ainda não há modelos esculpidos profissionalmente integrados nesta pasta. Os personagens
procedurais do jogo permanecem ativos até a entrada de arquivos que cumpram os requisitos
acima e passem por importação, teste de animação, validação visual e exportação Android.
