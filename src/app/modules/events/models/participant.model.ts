import { ParticipationStatus } from "./participation.model"

export type Participant = {
  avatar_url: string
  full_name: string
  id: string
  status: ParticipationStatus
  username: string
}