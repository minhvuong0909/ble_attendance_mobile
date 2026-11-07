import { screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { server } from '@/test/server'
import { signInAs, teacherUser, url } from '@/test/handlers'
import { renderApp } from '@/test/render'

const base = {
  id: 'c1',
  course_id: 'co1',
  course_code: 'PRM393',
  course_name: 'Lập trình di động',
  class_code: 'SE1901',
  semester: 'FA26',
  teacher_user_id: 'u-teacher',
  teacher_name: 'Giảng viên Demo',
  join_code: 'EFC63D',
  max_absence_percent: 20,
  rssi_threshold: -75,
  student_count: 2,
}

function api(fail = false) {
  const cls = { ...base }
  const log = { patches: [] as unknown[] }
  server.use(
    http.get(url('/classes/c1'), () => HttpResponse.json(cls)),
    http.get(url('/classes/c1/students'), () => HttpResponse.json([])),
    http.patch(url('/classes/c1/rssi'), async ({ request }) => {
      const body = (await request.json()) as { rssi_threshold: number }
      log.patches.push(body)
      if (fail) return HttpResponse.json({ detail: 'Bạn không được phân công lớp này', code: 'forbidden' }, { status: 403 })
      cls.rssi_threshold = body.rssi_threshold
      return HttpResponse.json(cls)
    }),
  )
  return log
}

const input = () => screen.getByLabelText('Ngưỡng RSSI (dBm)') as HTMLInputElement

describe('teacher RSSI setting', () => {
  it('shows the current threshold and keeps save disabled until it changes', async () => {
    signInAs(teacherUser)
    api()
    renderApp('/teacher/classes/c1')
    await screen.findByLabelText('Ngưỡng RSSI (dBm)')
    expect(input().value).toBe('-75')
    expect(screen.getByRole('button', { name: 'Lưu ngưỡng' })).toBeDisabled()
  })

  it('saves a typed value', async () => {
    signInAs(teacherUser)
    const log = api()
    renderApp('/teacher/classes/c1')
    const u = userEvent.setup()
    await screen.findByLabelText('Ngưỡng RSSI (dBm)')
    await u.clear(input())
    await u.type(input(), '-82')
    await u.click(screen.getByRole('button', { name: 'Lưu ngưỡng' }))
    await screen.findByText('Đã lưu ngưỡng RSSI')
    expect(log.patches).toEqual([{ rssi_threshold: -82 }])
    expect(screen.getByRole('button', { name: 'Lưu ngưỡng' })).toBeDisabled()
  })

  it('fills the value from a room-size preset', async () => {
    signInAs(teacherUser)
    const log = api()
    renderApp('/teacher/classes/c1')
    const u = userEvent.setup()
    await screen.findByLabelText('Ngưỡng RSSI (dBm)')
    await u.click(screen.getByRole('button', { name: /Phòng lớn/ }))
    expect(input().value).toBe('-85')
    await u.click(screen.getByRole('button', { name: 'Lưu ngưỡng' }))
    await screen.findByText('Đã lưu ngưỡng RSSI')
    expect(log.patches).toEqual([{ rssi_threshold: -85 }])
  })

  it('rejects out-of-range values without calling the API', async () => {
    signInAs(teacherUser)
    const log = api()
    renderApp('/teacher/classes/c1')
    const u = userEvent.setup()
    await screen.findByLabelText('Ngưỡng RSSI (dBm)')
    await u.clear(input())
    await u.type(input(), '-20')
    await u.click(screen.getByRole('button', { name: 'Lưu ngưỡng' }))
    expect(await screen.findByText('Ngưỡng RSSI từ -100 đến -30')).toBeInTheDocument()
    expect(log.patches).toEqual([])
  })

  it('shows the server error', async () => {
    signInAs(teacherUser)
    api(true)
    renderApp('/teacher/classes/c1')
    const u = userEvent.setup()
    await screen.findByLabelText('Ngưỡng RSSI (dBm)')
    await u.clear(input())
    await u.type(input(), '-90')
    await u.click(screen.getByRole('button', { name: 'Lưu ngưỡng' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Bạn không được phân công lớp này')
  })
})
