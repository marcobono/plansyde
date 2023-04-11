import { Component } from '@angular/core';
import { SupabaseService } from './core/supabase.service';
import { Observable } from 'rxjs';
import { Session } from '@supabase/supabase-js';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent {

  constructor(
    private readonly supabase: SupabaseService
  ) {
    this.session = this.supabase.session
  }

  session: Observable<Session | null>

}
