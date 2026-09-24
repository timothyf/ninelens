import { mount } from '@vue/test-utils'
import { ref } from 'vue'
import { describe, expect, it } from 'vitest'

import RecentGameLogsCard from '../RecentGameLogsCard.vue'

describe('RecentGameLogsCard', () => {
  it('renders the batting table with the requested ten-game limit', () => {
    const player = {
      gameLogs: {
        category: 'batting',
        batting: Array.from({ length: 30 }, (_, index) => ({ date: `2026-04-${String(index + 1).padStart(2, '0')}`, team: 'DET', opponent: '@ MIN', at_bats: 4, hits: 1 })),
        pitching: [],
      },
    }
    const wrapper = mount(RecentGameLogsCard, {
      global: {
        provide: {
          'player-profile-context': {
            player: ref(player),
            formatDate: (value) => value,
            formatBaseballStatValue: (key, value) => String(value),
          },
        },
      },
    })

    expect(wrapper.get('[data-test="recent-game-logs"] h2').text()).toBe('Game logs')
    expect(wrapper.get('select').element.value).toBe('10')
    expect(wrapper.findAll('tbody tr')).toHaveLength(10)
    expect(wrapper.get('tfoot').text()).toContain('Totals')
    expect(wrapper.get('tfoot').text()).toContain('40')
    expect(wrapper.get('tfoot').text()).toContain('10 games')
    expect(wrapper.text()).toContain('AB')
    expect(wrapper.text()).toContain('AVG')
  })

  it('changes the batting window and recalculates the displayed totals', async () => {
    const player = {
      gameLogs: {
        category: 'batting',
        batting: Array.from({ length: 30 }, (_, index) => ({ date: `2026-04-${String(index + 1).padStart(2, '0')}`, team: 'DET', opponent: '@ MIN', at_bats: 4, hits: 1 })),
        pitching: [],
      },
    }
    const wrapper = mount(RecentGameLogsCard, {
      global: {
        provide: {
          'player-profile-context': {
            player: ref(player),
            formatDate: (value) => value,
            formatBaseballStatValue: (key, value) => String(value),
          },
        },
      },
    })

    await wrapper.get('select').setValue('20')

    expect(wrapper.findAll('tbody tr')).toHaveLength(20)
    expect(wrapper.get('tfoot').text()).toContain('80')
    expect(wrapper.get('tfoot').text()).toContain('20 games')
  })
})
