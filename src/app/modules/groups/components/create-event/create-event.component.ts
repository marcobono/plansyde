import { Component, Inject, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { MatSnackBar } from '@angular/material/snack-bar';
import { CreateEventRequest } from 'src/app/modules/events/models/create-event-request.model';
import { EventsService } from 'src/app/modules/events/services/events.service';

@Component({
  selector: 'app-create-event',
  templateUrl: './create-event.component.html',
  styleUrls: ['./create-event.component.scss']
})
export class CreateEventComponent implements OnInit {
  
  hours: Array<number> =  Array.from({length: 24}).map((_, i) => i)
  minutes: Array<number> =  Array.from({length: 12}).map((_, i) => i*5)
  reloadRequestsOnClose = false
  private readonly today = new Date()
  form: FormGroup
  selected: Date = this.today;
  minDate = this.today

  constructor(
    private readonly eventService: EventsService,
    @Inject(MAT_DIALOG_DATA) protected readonly data: {
      groupId: number
      userId: string
      name: string
      description: string
    },
    public dialogRef: MatDialogRef<CreateEventComponent>,
    private formBuilder: FormBuilder,
    private readonly _snackBar: MatSnackBar
  ) {}

  get hoursOptions(): Array<number> {
    return this.isToday() 
      ? this.possibleHours
      : this.hours
  }

  get minutesOptions(): Array<number> {
    return this.isToday() && this.isCurrentHour()
      ? this.possibleMinutes
      : this.minutes
  }

  get possibleMinutes(): Array<number> {
    return this.minutes.slice().filter(minute => minute >= this.today.getMinutes())
  }

  get possibleHours(): Array<number> {
    const availableHours = this.hours.slice().filter(hour => hour >= this.today.getHours())
    if (!this.possibleMinutes.length) {
      availableHours.shift()
      return availableHours
    }
    return availableHours
  }

  isToday(): boolean {
    return this.selected.getDate() === this.today.getDate()
  }

  isCurrentHour(): boolean {
    return this.form && +this.form.value['hours'] === this.today.getHours()
  }

  ngOnInit(): void {
    this.createForm()
  }

  private createForm(): void {
    this.form = this.formBuilder.group({
      hours: [new Date().getHours(), [
        Validators.required
      ]],
      minutes: [this.possibleMinutes[0], [
        Validators.required
      ]]
    })
  }

  createEvent(): void {
    const {hours, minutes} = this.form.value
    const date = this.selected.setHours(hours, minutes)
    const body = new CreateEventRequest(
      this.data.name, this.data.description,
      this.data.userId, this.data.groupId,
      new Date(date)
    )
    this.eventService.createEvent(body).subscribe({
      next: () => {
        this.openSnackBar('Evento creato', '🎉')
        this.reloadRequestsOnClose = true
        this.closeDialog()
      },
      error: () => {
        this.openSnackBar('Si è verificato un errore', '😵')
        this.closeDialog()
      }
    })
  }

  closeDialog(): void {
    this.dialogRef.close(this.reloadRequestsOnClose)
  }

  openSnackBar(message: string, action: string) {
    this._snackBar.open(message, action, {
      duration: 5000,
      horizontalPosition: 'center',
      verticalPosition: 'top'
    });
  }
  
}
