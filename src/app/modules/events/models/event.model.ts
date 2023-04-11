import { Participant } from "./participant.model"

export type OngoingEvent = {
  creator_avatar_url: string
  creator_full_name: string
  creator_username: string
  description: string | null
  id: number
  name: string
  start: string
  participants: Array<Participant>
}