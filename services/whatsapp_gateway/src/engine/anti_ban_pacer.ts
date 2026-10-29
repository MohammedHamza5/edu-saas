import { WASocket } from '@whiskeysockets/baileys';

export interface PacerConfig {
  minDelayMs: number;
  maxDelayMs: number;
  microPauseBatchCount: number;
  microPauseDurationMs: number;
}

const DEFAULT_CONFIG: PacerConfig = {
  minDelayMs: 4000,
  maxDelayMs: 8000,
  microPauseBatchCount: 10,
  microPauseDurationMs: 35000
};

export class AntiBanPacer {
  private config: PacerConfig;
  private messageCount: number = 0;
  private consecutiveErrors: number = 0;
  private circuitBreakerTrippedUntil: number = 0;

  constructor(config: Partial<PacerConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  /**
   * Check if circuit breaker is currently preventing sends
   */
  public isCircuitTripped(): boolean {
    return Date.now() < this.circuitBreakerTrippedUntil;
  }

  public recordSuccess(): void {
    this.consecutiveErrors = 0;
    this.messageCount++;
  }

  public recordFailure(): void {
    this.consecutiveErrors++;
    if (this.consecutiveErrors >= 3) {
      // Trip circuit for 2 minutes to protect connection from aggressive retries
      this.circuitBreakerTrippedUntil = Date.now() + 120000;
      console.warn(`[AntiBanPacer] Circuit breaker tripped due to 3 consecutive failures. Pausing for 2 minutes.`);
    }
  }

  /**
   * Execute human delay and simulate typing presence before dispatching message.
   */
  public async paceAndSimulatePresence(sock: WASocket, jid: string): Promise<void> {
    // 1. Check if micro-pause is needed
    if (this.messageCount > 0 && this.messageCount % this.config.microPauseBatchCount === 0) {
      console.log(`[AntiBanPacer] Micro-pause triggered after ${this.messageCount} messages. Resting for ${this.config.microPauseDurationMs / 1000}s...`);
      await this.sleep(this.config.microPauseDurationMs);
    }

    // 2. Random human jitter delay (4-8 seconds)
    const jitter = Math.floor(
      Math.random() * (this.config.maxDelayMs - this.config.minDelayMs + 1) + this.config.minDelayMs
    );
    console.log(`[AntiBanPacer] Applying human pacing jitter: ${(jitter / 1000).toFixed(1)}s`);
    await this.sleep(jitter);

    // 3. Emulate presence: available -> composing -> pause
    try {
      await sock.sendPresenceUpdate('available');
      await sock.sendPresenceUpdate('composing', jid);
      
      // Simulate typing duration (1.5 - 2.5 seconds)
      const typingTime = Math.floor(Math.random() * 1000 + 1500);
      await this.sleep(typingTime);

      await sock.sendPresenceUpdate('paused', jid);
    } catch (err) {
      // Non-fatal if presence update fails, proceed to send message
      console.warn('[AntiBanPacer] Presence emulation warning:', (err as Error).message);
    }
  }

  /**
   * Adds dynamic subtle variance to message body to prevent exact hash matching
   */
  public humanizeMessage(originalBody: string): string {
    const timeFormatted = new Date().toLocaleTimeString('ar-EG', {
      timeZone: 'Africa/Cairo',
      hour: '2-digit',
      minute: '2-digit',
      hour12: true
    });

    // Subtle time stamp in Cairo timezone for uniqueness & traceability
    return `${originalBody.trim()}\n\n⏱️ [${timeFormatted}]`;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
