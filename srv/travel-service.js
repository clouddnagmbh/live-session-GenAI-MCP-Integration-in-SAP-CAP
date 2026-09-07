import cds from '@sap/cds'

/**
 * Assigns the next Travel ID when a new draft is created, so the Fiori
 * "Create" dialog does not prompt for a key — and so a live demo cannot
 * collide with an ID that already exists.
 */
export default class TravelService extends cds.ApplicationService {
  init() {
    const { Travels } = this.entities

    this.before('NEW', Travels.drafts, async req => {
      if (req.data.ID) return
      const [active, draft] = await Promise.all([
        SELECT.one`max(ID) as maxID`.from(Travels),
        SELECT.one`max(ID) as maxID`.from(Travels.drafts)
      ])
      req.data.ID = Math.max(active?.maxID ?? 0, draft?.maxID ?? 0) + 1
    })

    return super.init()
  }
}
