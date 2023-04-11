import { Injectable } from '@angular/core';
import { SupabaseClient } from '@supabase/supabase-js';
import { Observable, from, map } from 'rxjs';
import { SupabaseService } from 'src/app/core/supabase.service';
import { CreateEventRequest } from '../models/create-event-request.model';
import { OngoingEvent } from '../models/event.model';
import { CreateParticipationRequest } from '../models/create-participation-request.model';

@Injectable({
  providedIn: 'root'
})
export class EventsService {

  private supabase: SupabaseClient
  constructor(private readonly supabaseService: SupabaseService) {
    this.supabase = this.supabaseService.getClient()
  }

  createEvent(eventData: CreateEventRequest): Observable<any> {
    return from(this.supabase.from('events').insert(eventData)).pipe(
      map(response => response.data)
    )
  }

  getAllEvents(userId: string): Observable<OngoingEvent[]> {
    return from(this.supabase
      .rpc('get_user_events', {
        current_user_id: userId
      })
    ).pipe(
      map(response => response.data)
    )
  }

  createParticipation(body: CreateParticipationRequest): Observable<any> {
    return from(this.supabase
      .rpc('upsert_participation', body)
    ).pipe(
      map(response => response.data)
    )
  }

}

