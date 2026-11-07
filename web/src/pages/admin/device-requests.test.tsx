import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { server } from '@/test/server'
import { adminUser, signInAs, url } from '@/test/handlers'
import { renderApp } from '@/test/render'

interface Req {
  id: number
  student_user_id: string
  student_id: string
  student_name: string
  reason: string
  status: 'pending' | 'approved' | 'rejected'
  created_at: string
  resolved_at: string | null
}

const pending: Req = {
  id: 1,
  student_user_id: 's1',
  student_id: '25CE099',
  student_name: 'Nguyễn Văn A',
  reason: 'Đổi điện thoại mới',
  status: 'pending',
  created_at: '2026-11-06T03:00:00Z',
  resolved_at: null,
}

function api(initial: Req[]) {
  const rows = initial.map((r) => ({ ...r }))
  const log = { actions: [] as string[] }
  server.use(
    http.get(url('/admin/device-requests'), () => HttpResponse.json(rows)),
    http.post(url('/admin/device-requests/:id/:action'), ({ params }) => {
      const row = rows.find((r) => String(r.id) === params.id)!
      row.status = params.action === 'approve' ? 'approved' : 'rejected'
      log.actions.push(`${params.action}:${params.id}`)
      return HttpResponse.json(row)
    }),
  )
  return log
}

describe('admin device requests', () => {
  it('lists requests with student, reason and status', async () => {
    signInAs(adminUser)
    api([pending])
    renderApp('/admin/device-requests')
    expect(await screen.findByText('25CE099')).toBeInTheDocument()
    expect(screen.getByText('Nguyễn Văn A')).toBeInTheDocument()
    expect(screen.getByText('Đổi điện thoại mới')).toBeInTheDocument()
    expect(screen.getByText('Chờ duyệt')).toBeInTheDocument()
  })

  it('shows an empty state', async () => {
    signInAs(adminUser)
    api([])
    renderApp('/admin/device-requests')
    expect(await screen.findByText('Chưa có đơn đổi thiết bị nào')).toBeInTheDocument()
  })

  it('approves a pending request after confirmation', async () => {
    signInAs(adminUser)
    const log = api([pending])
    renderApp('/admin/device-requests')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Duyệt đơn 25CE099' }))
    const dialog = await screen.findByRole('alertdialog')
    await u.click(within(dialog).getByRole('button', { name: 'Duyệt' }))
    expect(await screen.findByText('Đã duyệt')).toBeInTheDocument()
    expect(log.actions).toEqual(['approve:1'])
  })

  it('rejects a pending request', async () => {
    signInAs(adminUser)
    const log = api([pending])
    renderApp('/admin/device-requests')
    const u = userEvent.setup()
    await u.click(await screen.findByRole('button', { name: 'Từ chối đơn 25CE099' }))
    const dialog = await screen.findByRole('alertdialog')
    await u.click(within(dialog).getByRole('button', { name: 'Từ chối' }))
    expect(await screen.findByText('Đã từ chối')).toBeInTheDocument()
    expect(log.actions).toEqual(['reject:1'])
  })

  it('has no actions for resolved requests', async () => {
    signInAs(adminUser)
    api([{ ...pending, status: 'approved', resolved_at: '2026-11-06T04:00:00Z' }])
    renderApp('/admin/device-requests')
    expect(await screen.findByText('Đã duyệt')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /Duyệt đơn/ })).not.toBeInTheDocument()
  })
})
