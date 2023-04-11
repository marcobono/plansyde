import { Component, OnInit } from '@angular/core';
import { map, switchMap } from 'rxjs';
import { SupabaseService } from 'src/app/core/supabase.service';
import { OngoingEvent } from '../../models/event.model';
import { EventsService } from '../../services/events.service';
import { MatDialog } from '@angular/material/dialog';
import { EventDetailsComponent } from '../../components/event-details/event-details.component';
import { MatSnackBar } from '@angular/material/snack-bar';

@Component({
  selector: 'app-events',
  templateUrl: './events.component.html',
  styleUrls: ['./events.component.scss']
})
export class EventsComponent implements OnInit{

  events: Array<OngoingEvent>

  constructor(
    private readonly supabase: SupabaseService,
    private readonly eventService: EventsService,
    private readonly dialog: MatDialog,
    private readonly _snackBar: MatSnackBar
  ) {}

  loading = false

  ngOnInit(): void {
    this.fetchEvents()
  }

  private fetchEvents(): void {
    this.loading = true
    this.supabase.session.pipe(
      map(session => session!.user),
      switchMap(user => {
        return this.eventService.getAllEvents(user.id)
      })
    ).subscribe({
      next: (data) => {
        this.loading = false
        this.events = data!
      },
      error: () => {
        this.openSnackBar('Si è verificato un errore', '😵')
      }
    })
  }

  openDialog(eventId: number): void {
    this.supabase.session.subscribe({
      next: (session) => {
        const { user } = session!
        const selectedEvent = this.events.find(event => event.id === eventId)
        const dialogRef = this.dialog.open(EventDetailsComponent, {
          width: '90vw', maxWidth: '90vw',
          data: { 
            event: selectedEvent,
            userId: user.id
          }
        });
        dialogRef.afterClosed().subscribe((reloadRequests: boolean) => {
          if (reloadRequests) {
            this.fetchEvents()
          }
        });
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
