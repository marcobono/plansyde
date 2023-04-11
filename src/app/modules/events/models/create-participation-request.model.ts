import { ParticipationStatus } from "./participation.model"

export class CreateParticipationRequest {

  current_event_id: number
  current_user_id: string
  current_status: ParticipationStatus

  constructor(
    event_id: number,
    user_id: string,
    status: ParticipationStatus,
  ) {
    this.current_event_id = event_id
    this.current_user_id = user_id
    this.current_status = status
  }
}