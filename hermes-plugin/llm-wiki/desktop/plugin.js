import { host, haptic, useValue } from '@hermes/plugin-sdk'
import { useState } from 'react'
import { jsx, jsxs } from 'react/jsx-runtime'

function WikiPane({ ctx }) {
  const cwd = useValue(host.state.cwd)
  const [path, setPath] = useState(cwd || '')
  const [report, setReport] = useState(null)
  const [error, setError] = useState('')

  const inspect = async () => {
    setError('')
    try {
      const result = await ctx.rest(`/status?path=${encodeURIComponent(path)}`)
      setReport(result)
      haptic('tap')
    } catch (reason) {
      setReport(null)
      setError(reason?.message || 'No readable llm-wiki found at this path.')
    }
  }

  return jsxs('div', {
    className: 'flex h-full flex-col gap-3 p-3 text-sm',
    children: [
      jsx('div', { className: 'font-medium', children: 'llm-wiki' }),
      jsx('div', { className: 'text-(--ui-text-tertiary)', children: 'Read-only topic wiki status.' }),
      jsx('input', {
        className: 'rounded border border-(--ui-stroke-secondary) px-2 py-1',
        value: path,
        placeholder: 'Topic wiki path',
        onChange: event => setPath(event.target.value),
      }),
      jsx('button', { className: 'rounded bg-(--ui-accent) px-2 py-1 text-(--ui-on-accent)', onClick: inspect, children: 'Inspect' }),
      error ? jsx('div', { className: 'text-(--ui-text-danger)', children: error }) : null,
      report ? jsxs('div', {
        className: 'flex flex-col gap-1 text-(--ui-text-secondary)',
        children: [
          jsx('div', { children: `Raw documents: ${report.raw_documents}` }),
          jsx('div', { children: `Compiled articles: ${report.wiki_articles}` }),
          jsx('div', { children: report.missing_required_directories.length ? `Missing: ${report.missing_required_directories.join(', ')}` : 'Required directories present.' }),
        ],
      }) : null,
    ],
  })
}

export default {
  id: 'llm-wiki',
  name: 'llm-wiki',
  defaultEnabled: false,
  register(ctx) {
    ctx.register({
      id: 'llm-wiki-pane',
      area: 'panes',
      data: { title: 'llm-wiki', placement: 'right', width: '320px' },
      render: () => jsx(WikiPane, { ctx }),
    })
  },
}
