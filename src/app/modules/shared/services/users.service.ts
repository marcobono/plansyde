import { Injectable } from '@angular/core';
import { SupabaseClient } from '@supabase/supabase-js';
import { from, map, Observable } from 'rxjs';
import { SupabaseService } from 'src/app/core/supabase.service';

@Injectable({
  providedIn: 'root'
})
export class UsersService {

  supabase: SupabaseClient
  constructor(private readonly supabaseService: SupabaseService) {
    this.supabase = this.supabaseService.getClient()
  }

  getUserByUsername(username: string): Observable<any> {
    return from(this.supabase
      .from('profiles')
      .select('*')
      .eq('username', username)
    ).pipe(
      map(response => response.data)
    )
  }
}
