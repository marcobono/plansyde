import { Profile } from "src/app/core/supabase.service"
import { OngoingEvent } from "../../events/models/event.model"

export type GroupDetail = {
  group_info: [GroupInfo]
  members: Array<Profile>
  friends_not_in_group: Array<Profile>
  events: Array<OngoingEvent>
}

export type GroupInfo = {
  created_at: string | Date
  creator_avatar_url: string
  creator_full_name: string
  creator_username: string
  description: string
  id: number
  name: string
}