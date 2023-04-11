import { Injectable } from "@angular/core";
import { Router, CanActivate, UrlTree } from "@angular/router";
import { map, Observable } from "rxjs";
import { SupabaseService } from "../supabase.service";

@Injectable({
  providedIn: 'root'
})
export class LoggedGuard implements CanActivate {
  constructor(private readonly supabase: SupabaseService,
    private readonly router: Router) {}
  canActivate(): boolean | UrlTree | Observable<boolean | UrlTree> | Promise<boolean | UrlTree> {

    return this.supabase.session.pipe(
      map((session) => {
        if (!!session)
          return true
        this.router.navigateByUrl('login')
        return false   
      })
    )
  }
}