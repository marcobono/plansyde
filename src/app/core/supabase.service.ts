import { Injectable } from '@angular/core'
import {
  AuthChangeEvent,
  AuthError,
  AuthResponse,
  AuthSession,
  createClient,
  Session,
  Subscription as SupaSubscription,
  SupabaseClient,
  User,
} from '@supabase/supabase-js'
import { from, map, Observable, of } from 'rxjs'
import { CreateGroupRequest } from '../modules/groups/models/create-group-request.model'
import { environment } from 'src/environments/environment'

export interface Profile {
  id?: string | null 
  username: string | null
  website?: string | null
  avatar_url: string | null
  full_name: string | null

  num_friends?: number
  num_groups?: number
}

@Injectable({
  providedIn: 'root',
})
export class SupabaseService {
  private readonly supabase: SupabaseClient
  private _session: AuthSession | null = null

  constructor() {
    this.supabase = createClient(environment.supabaseUrl, environment.supabaseKey)
    if (!environment.production) {
      this.supabase.auth.signInWithPassword({
        email: 'test@local.test',
        password: '123'
      })
    }
  }

  getClient(): SupabaseClient {
    return this.supabase
  }

  get isLoggedIn(): boolean {
    return !!this._session
  }

  get session(): Observable<AuthSession | null> {
    if(this._session) {
      return of(this._session)
    }
    return from(this.supabase.auth.getSession()).pipe(
      map(response => {
        this._session = response.data.session
        return response.data.session
      })
    )
  }

  profile(user: User): Observable<Profile | null> {
    return from(this.supabase
      .from('profiles')
      .select(`username, avatar_url, full_name, num_friends, num_groups`)
      .eq('id', user.id)
      .single()
    ).pipe(map( response => response.data))
  }

  authChanges(callback: (event: AuthChangeEvent, session: Session | null) => void): {data: {subscription: SupaSubscription}} {
    return this.supabase.auth.onAuthStateChange(callback)
  }

  signIn(email: string): Observable<AuthResponse> {
    return from(this.supabase.auth.signInWithOtp({ 
      email
    }))
  }

  signOut(): Observable<{error: AuthError | null}> {
    return from(this.supabase.auth.signOut())
  }

  updateProfile(profile: Partial<Profile>): Observable<any> {
    const update = {
      ...profile,
      updated_at: new Date(),
    }

    return from(this.supabase.from('profiles').upsert(update))
  }

  downLoadImage(path: string): Observable<Blob | null> {
    return from(this.supabase.storage.from('avatars').download(path)).pipe(
      map(response => response.data)
    )
  }

  uploadAvatar(filePath: string, file: File): Observable<{ path: string } | null> {
    return from(this.supabase.storage.from('avatars').upload(filePath, file)).pipe(
      map(response => response.data)
    )
  }

  createGroup(groupData: CreateGroupRequest): Observable<any> {
    return from(this.supabase.from('groups').insert(groupData)).pipe(
      map(response => response.data)
    )
  }
}