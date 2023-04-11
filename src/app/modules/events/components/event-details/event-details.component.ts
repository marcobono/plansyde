import { Component, Inject, OnInit } from '@angular/core';
import { EventsService } from '../../services/events.service';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { OngoingEvent } from '../../models/event.model';
import { ParticipationStatus } from '../../models/participation.model';
import { CreateParticipationRequest } from '../../models/create-participation-request.model';
import { Participant } from '../../models/participant.model';
import { MatSnackBar } from '@angular/material/snack-bar';

@Component({
  selector: 'app-event-details',
  templateUrl: './event-details.component.html',
  styleUrls: ['./event-details.component.scss']
})
export class EventDetailsComponent implements OnInit {

  reloadOnClose: boolean = false

  constructor(
    private readonly eventService: EventsService,
    @Inject(MAT_DIALOG_DATA) protected readonly data: {
      userId: string
      event: OngoingEvent
    },
    public dialogRef: MatDialogRef<EventDetailsComponent>,
    private readonly _snackBar: MatSnackBar
  ) {}

  participants: Array<Participant> = []
  nonParticipants: Array<Participant> = []
  isUserParticipating = false
  userParticipationStatus: ParticipationStatus | undefined

  ngOnInit(): void {
    this.mapParticipants()
    this.checkIfUserIsParticipating()
  }

  private checkIfUserIsParticipating(): void {
    this.isUserParticipating = this.data.event.participants.some(participant => participant.id === this.data.userId)
    this.isUserParticipating 
      ? this.userParticipationStatus = this.data.event.participants.find(participant => participant.id === this.data.userId)?.status
      : null
  }
  
  private mapParticipants(): void {    
    this.data.event.participants.forEach(participant => {
      switch(participant.status) {
        case 'yes':
          this.participants.push(participant)
          break
        case 'no':
          this.nonParticipants.push(participant)
          break
        default: break
      }
    });
  }

  closeDialog(): void {
    this.dialogRef.close(this.reloadOnClose)
  }

  addParticipation(participationStatus: ParticipationStatus): void {
    const body = new CreateParticipationRequest(
      this.data.event.id,
      this.data.userId,
      participationStatus
    )
    this.eventService.createParticipation(body).subscribe({
      next: () => {
        this.reloadOnClose = true
        body.current_status === 'yes'
          ? this.openSnackBar('Hai confermato la tua disponibilità', '👍')
          : this.openSnackBar('Sarà per la prossima', '👍')
        this.closeDialog()
      }, 
      error: () => {
        this.openSnackBar('Si è verificato un errore', '😵')
        this.closeDialog()
      }
    })
  } 

  openSnackBar(message: string, action: string) {
    this._snackBar.open(message, action, {
      duration: 5000,
      horizontalPosition: 'center',
      verticalPosition: 'top'
    });
  }

}
