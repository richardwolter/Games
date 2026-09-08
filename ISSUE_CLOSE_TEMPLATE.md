# Issue Closing Comment Template

Use this template when closing an issue. Keep it concise and always include:

## Format
```
Commit: <hash>
<resumo 1-2 frases sobre o trabalho feito>
Files: <arquivos principais modificados>
```

## Exemplos

### Issue #3: Extract master palette
```
Commit: 7fdc489
Palette integration completa: água lê cores do palette.tres, shader atualizado para cor local por tile.
Files: shaders/water.gdshader, Lake Cleanup/CLAUDE.md
```

### Issue #4: Update water shader colors
```
Commit: 7fdc489
Water shader agora pinta cores dirty/clean do mapa local (filth), não global. color_bite reduzido de 6.0 → 1.4 pra ler local sem dobrar FILTH_BITE.
Files: shaders/water.gdshader, scripts/iso.gd, scripts/ground.gd
```

## Diretrizes
- **Commit**: Hash curta do commit principal (7-8 chars)
- **Resumo**: 1-2 frases, o que foi feito e por quê (se não óbvio)
- **Files**: Arquivos principais tocados (não precisa listar todos)
- **Total**: Cabe em 3-4 linhas, legível de relance

## Quando aplicar
- Ao fechar qualquer issue
- Antes de clicar "Close Issue" no GitHub
- Vale copiar, adaptar o hash e resumo, colar
