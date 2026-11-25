# Pesquisa de personagens 3D — Mordor 3D

Data da verificação: 25/11/2026

Este documento separa **assets gratuitos utilizáveis** de **modelos com escultura profissional**.
A existência de licença comercial não significa que o estilo ou a qualidade atendam ao jogo.

## Candidatos gratuitos verificados para protótipo

### Gobkit Free Minions
- Página: https://gobkit.itch.io/gobkit-free-minions
- Manifesto: https://gobkit.com/api/free
- Licença declarada: CC0 1.0.
- Conteúdo declarado: oito personagens low-poly, GLB, rig humanoide, clipes baked de idle/attack/dead.
- Limitação: estilo low-poly e clipes em uma única timeline; não é escultura profissional nem substituto visual definitivo para heróis/boss.
- Uso recomendado: protótipo de inimigos secundários, após conferir os arquivos e a licença incluída no pacote.

### Rigged Characters Sampler — akuyzer
- Página: https://akuyzer.itch.io/rigged-characters-sampler-free
- Licença declarada pelo autor: uso pessoal e comercial permitido; não redistribuir os arquivos-fonte.
- Conteúdo declarado: três NPCs humanos rigados, GLB/FBX e texturas PBR; sem animações.
- Limitação: aparência humana genérica, disclosure de geração assistida por IA; não é escultura profissional de fantasia sombria.
- Uso recomendado: somente NPCs temporários, não protagonistas ou chefes.

### Grab3D Character Mixer
- Página: https://grab3d.com/tools/character-mixer/
- Licença declarada: CC0 1.0.
- Conteúdo declarado: exportação GLB rigada, esqueleto de 19 ossos e clipes idle/walk/run/wave/jump.
- Limitação: estilos cozy/blocky/low-poly e construção modular; não equivale a escultura high-end.
- Uso recomendado: validar retargeting e pipeline de animação, não como visual final.

## Decisão de produção

Nenhum dos candidatos acima é classificado como “modelo esculpido profissionalmente”.
Não integrar automaticamente esses personagens ao jogo final. Preservar os personagens procedurais
atuais até que exista um conjunto que cumpra os requisitos de qualidade, licença, rig e desempenho.

Para os personagens centrais (Senhor Sombrio, Nekravor e Oráculo), a opção gratuita encontrada
não atende ao padrão visual solicitado. Um asset premium pode ser avaliado, mas não será comprado
sem autorização explícita. Antes de qualquer integração, baixar e conferir o pacote, licença incluída,
topologia, UVs, materiais, esqueleto, clipes e tamanho real do GLB.

## Referências técnicas

- Godot 4.3 importa cenas glTF/GLB e suporta importação de animações:
  https://docs.godotengine.org/en/4.3/classes/class_resourceimporterscene.html
- Godot 4.3 oferece geração automática de LOD para cenas importadas; conferir deformações em malhas esqueléticas:
  https://docs.godotengine.org/en/latest/tutorials/3d/mesh_lod.html
- Retargeting humanoide depende de compatibilidade de nomes e orientação de repouso dos ossos:
  https://docs.godotengine.org/en/4.3/tutorials/assets_pipeline/retargeting_3d_skeletons.html
