import { RMQConnectionManager } from './rmq-connection-manager';
import { QueueManager } from './queue-manager';
import { QueueType } from '../types/queue-type';
import { QueueDestination } from '../types/queue-destination';
import { StepType } from '../../../../api/steps/types/step.interface';
import { randomUUID } from 'crypto';

export class Producer {
  private static connectionMgr: RMQConnectionManager;
  private static publishOptions = {
    persistent: true,
  };

  static init(connectionMgr: RMQConnectionManager) {
    Producer.connectionMgr = connectionMgr;
  }

  static async close() {
    return this.connectionMgr.close();
  }

  private static async sendJobToQueue(
    queue: QueueType,
    destination: QueueDestination,
    job: any
  ) {
    const contents = Buffer.from(JSON.stringify(job));
    const queueName = QueueManager.getQueueName(queue, destination);
    const options = {
      ...this.publishOptions,
      priority: job.metadata?.priority,
    };

    const channel = this.connectionMgr.channelObj;

    return new Promise<void>((resolve, reject) => {
      channel.sendToQueue(queueName, contents, options, (error) => {
        if (error) {
          reject(error);
          return;
        }

        resolve();
      });
    });
  }

  private static async publish(queue: QueueType, jobs: any[]) {
    const promises = [];

    for (const job of jobs) {
      promises.push(this.sendJobToQueue(queue, QueueDestination.PENDING, job));
    }

    return Promise.all(promises);
  }

  static async addToCompleted(queue: QueueType, job: any) {
    return this.sendJobToQueue(queue, QueueDestination.COMPLETED, job);
  }

  static async addToFailed(queue: QueueType, job: any) {
    return this.sendJobToQueue(queue, QueueDestination.FAILED, job);
  }

  static async requeueJob(queue: QueueType, job: any) {
    return this.sendJobToQueue(queue, QueueDestination.PENDING, job);
  }

  private static getStepDepthFromBulkJobs(jobs: any[]): number {
    const allStepDepths = new Set();
    let stepDepth: number;

    for (const job of jobs) {
      // handle job and jobData
      stepDepth = job.stepDepth;

      if (!stepDepth) stepDepth = job.data?.stepDepth;

      if (stepDepth) allStepDepths.add(+stepDepth);
    }

    // default to stepDepth of 1
    if (allStepDepths.size == 0) return 1;

    // get first value
    const it = allStepDepths.values();
    const first = it.next();
    stepDepth = first.value;

    return stepDepth;
  }

  private static getStepDepthFromJob(job: any): number {
    const stepDepth = this.getStepDepthFromBulkJobs([job]);

    return stepDepth;
  }

  static getNextStepDepthFromJob(job: any): number {
    const stepDepth = this.getStepDepthFromJob(job);

    return stepDepth + 1;
  }
  /**
   * Generate batchSize priorities for step jobs at a depth stepDepth
   * @param stepDepth (non-zero number)
   * @param batchSize
   * @returns
   */
  private static getBulkJobPriority(
    stepDepth: number,
    batchSize: number
  ): number[] {
    const priorities: number[] = [];

    // RabbitMQ 4.3 quorum queues provide priorities in the 0-31 range.
    const minJobPriority = 1;
    const maxJobPriority = 31;

    // max number of steps a journey can take
    const maxJourneyDepth = 50;

    // upperbound to maxJourneyDepth
    stepDepth = Math.min(stepDepth, maxJourneyDepth);

    // Map the 50 possible journey depths monotonically onto the 31 quorum
    // queue priority levels. Several adjacent depths intentionally share a
    // priority because the broker has fewer priority levels than journey
    // depths.
    const nextStepPriority = Math.max(
      minJobPriority,
      Math.min(
        maxJobPriority,
        Math.ceil((stepDepth * maxJobPriority) / maxJourneyDepth)
      )
    );

    for (let i = 0; i < batchSize; i++) {
      priorities.push(nextStepPriority);
    }

    return priorities;
  }

  private static getQueueForStepType(stepType: StepType) {
    const mapping = {
      [StepType.START]: QueueType.START_STEP,
      [StepType.EXIT]: QueueType.EXIT_STEP,
      [StepType.MESSAGE]: QueueType.MESSAGE_STEP,
      [StepType.TIME_WINDOW]: QueueType.TIME_WINDOW_STEP,
      [StepType.TIME_DELAY]: QueueType.TIME_DELAY_STEP,
      [StepType.ATTRIBUTE_BRANCH]: null,
      [StepType.LOOP]: QueueType.JUMP_TO_STEP,
      [StepType.AB_TEST]: null,
      [StepType.RANDOM_COHORT_BRANCH]: null,
      [StepType.WAIT_UNTIL_BRANCH]: QueueType.WAIT_UNTIL_STEP,
      [StepType.TRACKER]: null,
      [StepType.MULTISPLIT]: QueueType.MULTISPLIT_STEP,
      [StepType.EXPERIMENT]: QueueType.EXPERIMENT_STEP,
    };

    return mapping[stepType];
  }

  /**
   * create jobs from jobsData and add them in bulk it to a queue
   * @param queue
   * @param jobData
   * @returns
   */
  static async addBulk(queue: QueueType, jobsData: any[], name?: string) {
    const stepDepth = this.getStepDepthFromBulkJobs(jobsData);
    const priorities = this.getBulkJobPriority(stepDepth, jobsData.length);
    const jobs: {
      name: string;
      data: any;
      metadata: any;
    }[] = [];

    for (let i = 0; i < jobsData.length; i++) {
      jobs.push({
        name: name ?? queue,
        data: jobsData[i],
        metadata: {
          id: randomUUID(),
          priority: priorities[i],
        },
      });
    }

    return this.publish(queue, jobs);
  }

  /**
   * create a job from jobData and add it to a queue
   * @param queue
   * @param jobData
   * @returns
   */
  static async add(queue: QueueType, jobData: any, name?: string) {
    return this.addBulk(queue, [jobData], name);
  }

  /**
   * create a job from jobData and add it to a queue based on stepType
   * @param stepType
   * @param jobData
   * @returns
   */
  static async addByStepType(stepType: StepType, jobData: any, name?: string) {
    const queue = this.getQueueForStepType(stepType);

    return this.addBulk(queue, [jobData], name);
  }
}
