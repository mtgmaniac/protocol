import { Injectable } from '@angular/core';
import { Subject } from 'rxjs';

/** Hero to reroll; tray rolls on animation start then {@link ProtocolService.commitReroll}. */
export interface RerollAnimationPayload {
  heroIdx: number;
}

@Injectable({ providedIn: 'root' })
export class RerollAnimationRequestService {
  private readonly requests = new Subject<RerollAnimationPayload>();
  readonly requests$ = this.requests.asObservable();

  emit(payload: RerollAnimationPayload): void {
    this.requests.next(payload);
  }
}
