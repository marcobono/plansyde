import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { EventsRoutingModule } from './events-routing.module';
import { EventsComponent } from './pages/events/events.component';
import { SharedModule } from '../shared/shared.module';
import { EventDetailsComponent } from './components/event-details/event-details.component';

@NgModule({
  declarations: [
    EventsComponent,
    EventDetailsComponent
  ],
  imports: [
    CommonModule,
    EventsRoutingModule,
    SharedModule
  ]
})
export class EventsModule { }
